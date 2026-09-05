import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/services/reading_scheduler.dart';

/// What the Today screen renders.
@immutable
class TodayState {
  const TodayState({
    this.collection,
    this.hadith,
    this.progress,
    this.isRead = false,
  });

  /// No book chosen yet.
  static const TodayState empty = TodayState();

  final HadithCollection? collection;

  /// The hadith on screen. Null when the book is finished or nothing is chosen.
  final Hadith? hadith;

  final ReadingProgress? progress;

  /// Whether [hadith] is marked read.
  final bool isRead;

  bool get hasCollection => collection != null;

  /// True once every hadith in the collection has been read.
  bool get isCollectionComplete => progress?.isComplete ?? false;

  int get ordinal => hadith?.ordinal ?? progress?.currentOrdinal ?? 1;

  int get total => progress?.totalHadith ?? collection?.totalHadith ?? 0;

  bool get hasPrevious => ordinal > 1;

  bool get hasNext => ordinal < total;
}

/// Drives the Today screen.
///
/// Position rules live in [ReadingScheduler]; this controller only decides
/// *when* to apply them. Browsing with Previous/Next pins a position for the
/// session so a rebuild cannot yank the reader back, while a genuine refresh
/// (app resume, notification tap) lets the book roll forward normally.
class TodayController extends AsyncNotifier<TodayState> {
  int? _pinnedOrdinal;
  String? _pinnedCollectionId;

  @override
  Future<TodayState> build() async {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final String? collectionId = preferences.currentCollectionId;

    if (collectionId == null) return TodayState.empty;

    // Changing books drops any pinned browsing position.
    if (_pinnedCollectionId != collectionId) {
      _pinnedCollectionId = collectionId;
      _pinnedOrdinal = null;
    }

    final HadithRepository hadithRepository = ref.watch(hadithRepositoryProvider);
    final ProgressRepository progressRepository =
        ref.watch(progressRepositoryProvider);

    // First open of a book copies it into local storage; afterwards this is a
    // cheap no-op.
    final HadithCollection collection =
        await hadithRepository.installCollection(collectionId);
    final int total = collection.totalHadith;
    if (total <= 0) throw DatasetUnavailableException(collectionId);

    ReadingProgress progress =
        await progressRepository.progressFor(collectionId, total);
    final int? firstUnread =
        await progressRepository.firstUnreadOrdinal(collectionId, total);

    final int ordinal = _pinnedOrdinal ??
        ReadingScheduler.resolveTodaysOrdinal(
          progress: progress,
          firstUnreadOrdinal: firstUnread,
          notificationPreferences: ref.watch(notificationPreferencesProvider),
          now: ref.watch(clockProvider)(),
        );

    if (ordinal != progress.currentOrdinal) {
      progress = await progressRepository.setCurrentOrdinal(
        collectionId,
        ordinal,
        total,
      );
    }

    final Hadith? hadith = await hadithRepository.hadithAt(collectionId, ordinal);
    final bool isRead = hadith != null &&
        await progressRepository.isRead(collectionId, hadith.id);

    return TodayState(
      collection: collection,
      hadith: hadith,
      progress: progress,
      isRead: isRead,
    );
  }

  /// Re-reads everything and lets the position roll forward if a new reading
  /// period has begun. Called on app resume and on notification taps.
  Future<void> refresh() async {
    _pinnedOrdinal = null;
    ref.invalidateSelf();
    await future;
  }

  /// Marks the hadith on screen as read. Only this one — never a range.
  Future<void> markRead() => _setRead(true);

  Future<void> markUnread() => _setRead(false);

  Future<void> _setRead(bool read) async {
    final TodayState? current = state.value;
    final Hadith? hadith = current?.hadith;
    final HadithCollection? collection = current?.collection;
    if (hadith == null || collection == null) return;

    final ProgressRepository repository = ref.read(progressRepositoryProvider);
    if (read) {
      await repository.markRead(
        collection.id,
        hadith.id,
        hadith.ordinal,
        collection.totalHadith,
        at: ref.read(clockProvider)(),
      );
    } else {
      await repository.markUnread(
        collection.id,
        hadith.id,
        collection.totalHadith,
      );
    }

    // Hold the reader on the hadith they just acted on.
    _pinnedOrdinal = hadith.ordinal;
    _invalidateProgressViews();
    ref.invalidateSelf();
    await future;
  }

  /// Marks today's hadith read because the reader arrived from a reminder.
  ///
  /// Called only on a notification tap — a reminder firing on its own never
  /// changes progress.
  Future<void> markReadFromNotification() async {
    _pinnedOrdinal = null;
    ref.invalidateSelf();
    final TodayState refreshed = await future;
    if (refreshed.hadith == null || refreshed.isRead) return;
    await markRead();
  }

  Future<void> goToNext() async {
    final TodayState? current = state.value;
    if (current == null || !current.hasNext) return;
    await _moveTo(current.ordinal + 1);
  }

  Future<void> goToPrevious() async {
    final TodayState? current = state.value;
    if (current == null || !current.hasPrevious) return;
    await _moveTo(current.ordinal - 1);
  }

  /// Jumps to a specific position, e.g. "continue reading" from the library.
  Future<void> goTo(int ordinal) => _moveTo(ordinal);

  Future<void> _moveTo(int ordinal) async {
    final TodayState? current = state.value;
    final HadithCollection? collection = current?.collection;
    if (collection == null) return;
    final int target = ordinal.clamp(1, collection.totalHadith);

    // Moving through the book is browsing, not reading: nothing in between is
    // marked read, and the position sticks until the next refresh.
    _pinnedOrdinal = target;
    await ref.read(progressRepositoryProvider).setCurrentOrdinal(
          collection.id,
          target,
          collection.totalHadith,
        );
    ref.invalidateSelf();
    await future;
  }

  /// Clears read state so a finished book can be read again from the start.
  Future<void> restartCollection() async {
    final HadithCollection? collection = state.value?.collection;
    if (collection == null) return;
    await ref.read(progressRepositoryProvider).resetCollection(
          collection.id,
          collection.totalHadith,
        );
    _pinnedOrdinal = null;
    _invalidateProgressViews();
    ref.invalidateSelf();
    await future;
  }

  void _invalidateProgressViews() {
    ref.invalidate(libraryProvider);
    ref.invalidate(startedCollectionsProvider);
  }
}

final AsyncNotifierProvider<TodayController, TodayState> todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(TodayController.new);
