import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content/asset_hadith_content_source.dart';
import '../data/local/app_database.dart';
import '../data/local/hadith_dao.dart';
import '../data/local/preferences_store.dart';
import '../data/local/progress_dao.dart';
import '../data/notifications/local_notification_scheduler.dart';
import '../data/repositories/hadith_repository_impl.dart';
import '../data/repositories/progress_repository_impl.dart';
import '../domain/entities/hadith_collection.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/entities/user_preferences.dart';
import '../domain/repositories/hadith_content_source.dart';
import '../domain/repositories/hadith_repository.dart';
import '../domain/repositories/notification_scheduler.dart';
import '../domain/repositories/preferences_repository.dart';
import '../domain/repositories/progress_repository.dart';

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

final Provider<PreferencesRepository> preferencesRepositoryProvider =
    Provider<PreferencesRepository>(
  (Ref ref) => PreferencesStore(ref.watch(sharedPreferencesProvider)),
);

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((Ref ref) => LocalNotificationScheduler());

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
  Future<void> applyToScheduler() async {
    final NotificationScheduler scheduler =
        ref.read(notificationSchedulerProvider);
    final String? collectionId =
        ref.read(userPreferencesProvider).currentCollectionId;
    String? title;
    if (collectionId != null) {
      final HadithCollection? collection =
          await ref.read(hadithRepositoryProvider).collection(collectionId);
      title = collection?.titleEnglish;
    }
    await scheduler.reschedule(
      preferences: state,
      collectionId: collectionId,
      collectionTitle: title,
    );
    ref.invalidate(notificationPermissionProvider);
  }
}

final NotifierProvider<NotificationPreferencesController,
        NotificationPreferences> notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

/// Whether the OS currently allows notifications. Re-read whenever the app
/// resumes, because the reader may have changed it in system settings.
final FutureProvider<NotificationPermissionStatus>
    notificationPermissionProvider =
    FutureProvider<NotificationPermissionStatus>(
  (Ref ref) => ref.watch(notificationSchedulerProvider).permissionStatus(),
);
