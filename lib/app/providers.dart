import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content/asset_hadith_content_source.dart';
import '../data/local/app_database.dart';
import '../data/local/favourites_dao.dart';
import '../data/local/hadith_dao.dart';
import '../data/local/preferences_store.dart';
import '../data/local/progress_dao.dart';
import '../data/local/random_pick_dao.dart';
import '../data/notifications/local_notification_scheduler.dart';
import '../data/repositories/favourites_repository_impl.dart';
import '../data/repositories/hadith_repository_impl.dart';
import '../data/repositories/progress_repository_impl.dart';
import '../data/speech/flutter_tts_speech_synthesizer.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/hadith_collection.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/entities/user_preferences.dart';
import '../domain/repositories/favourites_repository.dart';
import '../domain/repositories/hadith_content_source.dart';
import '../domain/repositories/hadith_repository.dart';
import '../domain/repositories/notification_scheduler.dart';
import '../domain/repositories/preferences_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/random_pick_repository.dart';
import '../domain/repositories/speech_synthesizer.dart';
import '../domain/services/reminder_schedule.dart';
import 'random_selection.dart';
import 'reminder_planner.dart';

/// Thrown if a provider that must be overridden at startup is read directly.
Never _mustOverride(String name) =>
    throw StateError('$name must be overridden in ProviderScope.');

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// The clock, as a seam.
///
/// Everything that asks "has a new reading period begun?" goes through here, so
/// tests can advance days without waiting for them.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Overridden in `main()` once shared preferences have loaded.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((Ref ref) => _mustOverride('sharedPreferencesProvider'));

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// The single seam for hadith content. Override this to read from an API, a
/// downloaded pack, or a publisher's SDK instead of bundled assets — nothing
/// above this line changes.
final Provider<HadithContentSource> hadithContentSourceProvider =
    Provider<HadithContentSource>((Ref ref) => AssetHadithContentSource());

final Provider<HadithDao> hadithDaoProvider =
    Provider<HadithDao>((Ref ref) => HadithDao(ref.watch(appDatabaseProvider)));

final Provider<ProgressDao> progressDaoProvider = Provider<ProgressDao>(
  (Ref ref) => ProgressDao(ref.watch(appDatabaseProvider)),
);

final Provider<FavouritesDao> favouritesDaoProvider = Provider<FavouritesDao>(
  (Ref ref) => FavouritesDao(ref.watch(appDatabaseProvider)),
);

final Provider<HadithRepository> hadithRepositoryProvider =
    Provider<HadithRepository>(
  (Ref ref) => HadithRepositoryImpl(
    contentSource: ref.watch(hadithContentSourceProvider),
    dao: ref.watch(hadithDaoProvider),
  ),
);

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>(
  (Ref ref) => ProgressRepositoryImpl(ref.watch(progressDaoProvider)),
);

final Provider<FavouritesRepository> favouritesRepositoryProvider =
    Provider<FavouritesRepository>(
  (Ref ref) => FavouritesRepositoryImpl(
    favouritesDao: ref.watch(favouritesDaoProvider),
    hadithDao: ref.watch(hadithDaoProvider),
  ),
);

/// Randomness, as a seam, so tests can make random mode repeatable.
final Provider<Random> randomProvider = Provider<Random>((Ref ref) => Random());

final Provider<RandomPickRepository> randomPickRepositoryProvider =
    Provider<RandomPickRepository>(
  (Ref ref) => RandomPickDao(ref.watch(appDatabaseProvider)),
);

final Provider<RandomSelection> randomSelectionProvider =
    Provider<RandomSelection>(
  (Ref ref) => RandomSelection(
    hadithRepository: ref.watch(hadithRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    picks: ref.watch(randomPickRepositoryProvider),
    random: ref.watch(randomProvider),
  ),
);

final Provider<ReminderPlanner> reminderPlannerProvider =
    Provider<ReminderPlanner>(
  (Ref ref) => ReminderPlanner(
    hadithRepository: ref.watch(hadithRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    randomSelection: ref.watch(randomSelectionProvider),
  ),
);

final Provider<PreferencesRepository> preferencesRepositoryProvider =
    Provider<PreferencesRepository>(
  (Ref ref) => PreferencesStore(ref.watch(sharedPreferencesProvider)),
);

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((Ref ref) => LocalNotificationScheduler());

/// Text-to-speech for the translation. Disposed with the scope so the engine
/// is released when the app shuts down.
final Provider<SpeechSynthesizer> speechSynthesizerProvider =
    Provider<SpeechSynthesizer>((Ref ref) {
  final SpeechSynthesizer synthesizer = FlutterTtsSpeechSynthesizer();
  ref.onDispose(synthesizer.dispose);
  return synthesizer;
});

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

/// Preferences read once before the first frame, so the UI never has to render
/// a loading state for something as basic as the theme.
final Provider<UserPreferences> initialUserPreferencesProvider =
    Provider<UserPreferences>((Ref ref) => _mustOverride('initialUserPreferencesProvider'));

final Provider<NotificationPreferences> initialNotificationPreferencesProvider =
    Provider<NotificationPreferences>(
  (Ref ref) => _mustOverride('initialNotificationPreferencesProvider'),
);

class UserPreferencesController extends Notifier<UserPreferences> {
  @override
  UserPreferences build() => ref.watch(initialUserPreferencesProvider);

  Future<void> update(UserPreferences next) async {
    state = next;
    await ref.read(preferencesRepositoryProvider).saveUserPreferences(next);
  }

  Future<void> setCurrentCollection(String collectionId) =>
      update(state.copyWith(currentCollectionId: collectionId));

  /// Makes [collectionId] the current book and reads it in order — what
  /// choosing a book to read from the library or progress screens means.
  Future<void> readInOrder(String collectionId) => update(
        state.copyWith(
          currentCollectionId: collectionId,
          readingOrder: ReadingOrder.sequential,
        ),
      );

  /// Switches between reading in order and random, and re-arms reminders,
  /// whose hadith depend on it.
  Future<void> setReadingOrder(ReadingOrder order) async {
    if (order == state.readingOrder) return;
    await update(state.copyWith(readingOrder: order));
    await ref.read(notificationPreferencesProvider.notifier).applyToScheduler();
  }

  /// Chooses the books random mode draws from.
  ///
  /// Picks already made for this period and later came from the old books, so
  /// they are forgotten and drawn again from the new ones.
  Future<void> setRandomPool(List<String> collectionIds) async {
    if (collectionIds.isEmpty) return;
    await update(state.copyWith(randomCollectionIds: collectionIds));
    final DateTime periodStart =
        ReminderSchedule(ref.read(notificationPreferencesProvider))
            .currentPeriodStart(ref.read(clockProvider)());
    await ref.read(randomSelectionProvider).forgetFrom(periodStart);
    await ref.read(notificationPreferencesProvider.notifier).applyToScheduler();
  }

  Future<void> completeOnboarding() =>
      update(state.copyWith(onboardingComplete: true));
}

final NotifierProvider<UserPreferencesController, UserPreferences>
    userPreferencesProvider =
    NotifierProvider<UserPreferencesController, UserPreferences>(
  UserPreferencesController.new,
);

class NotificationPreferencesController
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() =>
      ref.watch(initialNotificationPreferencesProvider);

  /// Persists [next] and re-arms the OS reminders to match.
  ///
  /// Rescheduling always goes through here, so a frequency, time or book change
  /// can never leave a stale reminder behind.
  Future<void> update(NotificationPreferences next) async {
    state = next;
    await ref.read(preferencesRepositoryProvider)
        .saveNotificationPreferences(next);
    await applyToScheduler();
  }

  /// Re-arms the OS reminders from the current preferences and current book.
  ///
  /// Never throws. Reminders are an accessory to reading, and the platform can
  /// refuse to arm one for reasons outside the app's control — a permission
  /// withdrawn mid-call, an OEM alarm quota. A settings screen that threw on
  /// the way out would be a worse outcome than a reminder that did not arm.
  Future<void> applyToScheduler() async {
    try {
      final NotificationScheduler scheduler =
          ref.read(notificationSchedulerProvider);
      final UserPreferences user = ref.read(userPreferencesProvider);
      final String? collectionId = user.currentCollectionId;
      String? title;
      if (collectionId != null) {
        final HadithCollection? collection =
            await ref.read(hadithRepositoryProvider).collection(collectionId);
        title = collection?.titleEnglish;
      }
      // Planned first: it can take a moment, and the preferences armed must be
      // the ones current when arming happens, not when planning began.
      final List<PlannedReminder> planned = await _plan(user);
      await scheduler.reschedule(
        preferences: state,
        collectionId: collectionId,
        collectionTitle: title,
        planned: planned,
      );
    } on Object catch (error, stack) {
      debugPrint('Daily Hadith: could not arm reminders: $error\n$stack');
    }
    ref.invalidate(reminderReadinessProvider);
  }

  /// The reminders that carry their hadith, or none when the reader wants
  /// plain invitations.
  ///
  /// A plan that cannot be made is not a reason to go without reminders: the
  /// plain ones are armed instead.
  Future<List<PlannedReminder>> _plan(UserPreferences user) async {
    if (!state.enabled || !state.showHadithPreview) {
      return const <PlannedReminder>[];
    }
    try {
      return await ref.read(reminderPlannerProvider).plan(
            notifications: state,
            user: user,
            now: ref.read(clockProvider)(),
          );
    } on Object catch (error, stack) {
      debugPrint('Daily Hadith: could not plan reminder previews: $error\n'
          '$stack');
      return const <PlannedReminder>[];
    }
  }

  /// Re-arms reminders when their hadith may have changed — something was
  /// marked read or unread, or a new random hadith was drawn. Plain
  /// invitations say the same thing either way, so they are left alone.
  Future<void> refreshPreviews() async {
    if (!state.enabled || !state.showHadithPreview) return;
    await applyToScheduler();
  }
}

final NotifierProvider<NotificationPreferencesController,
        NotificationPreferences> notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

/// What the operating system currently allows reminders to do — arrive at
/// all, arrive on the minute, survive the phone putting the app to sleep.
///
/// Re-read whenever the app resumes, because the reader may have changed any
/// of it in system settings while the app was in the background.
final FutureProvider<ReminderReadiness> reminderReadinessProvider =
    FutureProvider<ReminderReadiness>(
  (Ref ref) => ref.watch(notificationSchedulerProvider).readiness(),
);
