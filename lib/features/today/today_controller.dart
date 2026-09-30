import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../app/random_selection.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/random_pick.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/services/reading_scheduler.dart';
import '../../domain/services/reminder_schedule.dart';

/// What the Today screen renders.
@immutable
class TodayState {
  const TodayState({
    this.collection,
    this.hadith,
    this.progress,
    this.isRead = false,
    this.order = ReadingOrder.sequential,
    this.poolSize = 0,
    this.poolRead = 0,
    this.poolTotal = 0,
  });

  /// No book chosen yet.
  static const TodayState empty = TodayState();

  /// How [hadith] was chosen: the next in its book, or at random for this
  /// period from the reader's chosen books.
  final ReadingOrder order;

  bool get isRandom => order == ReadingOrder.random;

  /// Random mode only: how many books it draws from, and how much of them has
  /// been read.
  final int poolSize;
  final int poolRead;
  final int poolTotal;

  final HadithCollection? collection;

  /// The hadith on screen. Null when the book is finished or nothing is chosen.
  final Hadith? hadith;

  final ReadingProgress? progress;

  /// Whether [hadith] is marked read.
  final bool isRead;

  bool get hasCollection => collection != null;

  /// True once every hadith in the collection has been read. Random mode has
  /// no end: once everything is read it starts drawing from the whole pool.
  bool get isCollectionComplete =>
      !isRandom && (progress?.isComplete ?? false);

  int get ordinal => hadith?.ordinal ?? progress?.currentOrdinal ?? 1;

  int get total => progress?.totalHadith ?? collection?.totalHadith ?? 0;

  /// Paging through a book only means something when reading it in order.
  bool get hasPrevious => !isRandom && ordinal > 1;

  bool get hasNext => !isRandom && ordinal < total;
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
    if (preferences.isRandom) return _buildRandom(preferences);

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

  /// Random mode: this period's pick from the reader's chosen books.
  Future<TodayState> _buildRandom(UserPreferences preferences) async {
    final RandomSelection selection = ref.watch(randomSelectionProvider);
    final HadithRepository hadithRepository = ref.watch(hadithRepositoryProvider);
    final ProgressRepository progressRepository =
        ref.watch(progressRepositoryProvider);

    final List<HadithCollection> pool =
        await selection.readablePool(preferences.randomPool);
    if (pool.isEmpty) {
      return const TodayState(order: ReadingOrder.random);
    }

    final DateTime periodStart =
        ReminderSchedule(ref.watch(notificationPreferencesProvider))
            .currentPeriodStart(ref.watch(clockProvider)());

    RandomPick? pick = await selection.pickFor(periodStart, pool);
    HadithCollection? collection;
    Hadith? hadith;
    // A pick can outlive the text it points at — a dataset re-imported with
    // fewer entries — so a missing hadith is replaced rather than shown as an
    // error. Twice is plenty; the pick is only ever stale, never cursed.
    for (int attempt = 0; attempt < 2 && pick != null; attempt++) {
      collection = await hadithRepository.installCollection(pick.collectionId);
      hadith = await hadithRepository.hadithAt(pick.collectionId, pick.ordinal);
      if (hadith != null) break;
      pick = await selection.pickFor(periodStart, pool, replace: true);
    }
    if (pick == null || collection == null || hadith == null) {
      return const TodayState(order: ReadingOrder.random);
    }

    int poolRead = 0;
    int poolTotal = 0;
    ReadingProgress? progress;
    for (final HadithCollection book in pool) {
      final ReadingProgress bookProgress =
          await progressRepository.progressFor(book.id, book.totalHadith);
      poolRead += bookProgress.totalRead;
      poolTotal += book.totalHadith;
      if (book.id == collection.id) progress = bookProgress;
    }
    progress ??= await progressRepository.progressFor(
      collection.id,
      collection.totalHadith,
    );

    return TodayState(
      collection: collection,
      hadith: hadith,
      progress: progress,
      isRead: await progressRepository.isRead(collection.id, hadith.id),
      order: ReadingOrder.random,
      poolSize: pool.length,
      poolRead: poolRead,
      poolTotal: poolTotal,
    );
  }

  /// Random mode: draws a different hadith for this period.
  Future<void> showAnother() async {
    final UserPreferences preferences = ref.read(userPreferencesProvider);
    if (!preferences.isRandom) return;
    final RandomSelection selection = ref.read(randomSelectionProvider);
    final DateTime periodStart =
        ReminderSchedule(ref.read(notificationPreferencesProvider))
            .currentPeriodStart(ref.read(clockProvider)());
    await selection.pickFor(
      periodStart,
      await selection.readablePool(preferences.randomPool),
      replace: true,
    );
    ref.invalidateSelf();
    await future;
  }

  /// Opens the hadith a reminder showed, and marks it read.
  ///
  /// In order, that moves the book to it. At random, it becomes this period's
  /// hadith, so it stays on screen until the next reminder.
  Future<void> openFromReminder(String collectionId, int ordinal) async {
    final UserPreferences preferences = ref.read(userPreferencesProvider);
    if (preferences.isRandom) {
      final DateTime periodStart =
          ReminderSchedule(ref.read(notificationPreferencesProvider))
              .currentPeriodStart(ref.read(clockProvider)());
      await ref.read(randomSelectionProvider).adopt(
            RandomPick(
              periodStart: periodStart,
              collectionId: collectionId,
              ordinal: ordinal,
            ),
          );
      _pinnedOrdinal = null;
      ref.invalidateSelf();
    } else {
      if (preferences.currentCollectionId != collectionId) {
        await ref
            .read(userPreferencesProvider.notifier)
            .setCurrentCollection(collectionId);
        // Changing the book rebuilds this controller, which drops any pinned
        // position; wait for that before pinning a new one.
        await future;
      }
      final HadithCollection collection = await ref
          .read(hadithRepositoryProvider)
          .installCollection(collectionId);
      final int target = ordinal.clamp(1, collection.totalHadith);
      _pinnedCollectionId = collectionId;
      _pinnedOrdinal = target;
      await ref.read(progressRepositoryProvider).setCurrentOrdinal(
            collectionId,
            target,
            collection.totalHadith,
          );
      ref.invalidateSelf();
    }
    final TodayState opened = await future;
    if (opened.hadith == null || opened.isRead) return;
    await markRead();
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
        // A random hadith is read where it stands; the reader's place in
        // that book is theirs to keep.
        movePosition: !current!.isRandom,
      );
    } else {
      await repository.markUnread(
        collection.id,
        hadith.id,
        collection.totalHadith,
      );
    }

    // Hold the reader on the hadith they just acted on. Random mode holds
    // itself: the pick is stored for the period.
    if (!current!.isRandom) _pinnedOrdinal = hadith.ordinal;
    _invalidateProgressViews();
    ref.invalidateSelf();
    await future;
    // What the reader has read decides what upcoming reminders carry.
    unawaited(
      ref.read(notificationPreferencesProvider.notifier).refreshPreviews(),
    );
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
