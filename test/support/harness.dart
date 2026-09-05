import 'package:daily_hadith/app/app.dart';
import 'package:daily_hadith/app/providers.dart';
import 'package:daily_hadith/data/local/app_database.dart';
import 'package:daily_hadith/data/local/preferences_store.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/entities/user_preferences.dart';
import 'package:daily_hadith/domain/repositories/hadith_content_source.dart';
import 'package:daily_hadith/features/splash/splash_screen.dart';
import 'package:daily_hadith/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

/// A clock the test can move forward.
class TestClock {
  TestClock(this.now);

  DateTime now;

  void advanceDays(int days) =>
      now = DateTime(now.year, now.month, now.day + days, now.hour, now.minute);

  void advanceHours(int hours) => now = now.add(Duration(hours: hours));
}

/// A fully wired app running against in-memory storage and fake platform
/// services. Everything above the data layer is the real thing.
class TestHarness {
  TestHarness._({
    required this.clock,
    required this.contentSource,
    required this.scheduler,
    required this.database,
    required this.overrides,
  });

  static Future<TestHarness> create({
    FakeContentSource? contentSource,
    FakeNotificationScheduler? scheduler,
    DateTime? now,
    Map<String, Object> initialPreferences = const <String, Object>{},
  }) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues(initialPreferences);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PreferencesStore store = PreferencesStore(prefs);
    final UserPreferences userPreferences = await store.loadUserPreferences();
    final NotificationPreferences notificationPreferences =
        await store.loadNotificationPreferences();

    final AppDatabase database = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    final FakeContentSource source =
        contentSource ?? FakeContentSource.single(count: 10);
    final FakeNotificationScheduler fakeScheduler =
        scheduler ?? FakeNotificationScheduler();
    final TestClock clock = TestClock(now ?? DateTime(2026, 1, 7, 9, 0));

    return TestHarness._(
      clock: clock,
      contentSource: source,
      scheduler: fakeScheduler,
      database: database,
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialUserPreferencesProvider.overrideWithValue(userPreferences),
        initialNotificationPreferencesProvider
            .overrideWithValue(notificationPreferences),
        appDatabaseProvider.overrideWithValue(database),
        hadithContentSourceProvider
            .overrideWith((Ref ref) => source as HadithContentSource),
        notificationSchedulerProvider.overrideWithValue(fakeScheduler),
        clockProvider.overrideWithValue(() => clock.now),
      ],
    );
  }

  final TestClock clock;
  final FakeContentSource contentSource;
  final FakeNotificationScheduler scheduler;
  final AppDatabase database;
  final List<Override> overrides;

  ProviderContainer? _container;

  /// The container behind the running app, for reading state in assertions.
  ProviderContainer get container => _container!;

  /// Mounts the real app and settles the startup work.
  Future<void> pumpApp(WidgetTester tester) async {
    final ProviderContainer container =
        ProviderContainer(overrides: overrides);
    _container = container;
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DailyHadithApp(),
      ),
    );
    await settle(tester);
  }

  /// Pumps until the app stops rebuilding.
  ///
  /// [WidgetTester.pumpAndSettle] alone is not enough here: startup chains
  /// several futures (database open, install, progress read), each of which
  /// schedules another frame.
  Future<void> settle(WidgetTester tester) async {
    // Two things have to make progress here, and they need different treatment:
    //
    //  * The database runs real asynchronous I/O, which the fake clock inside a
    //    widget test does not advance — `runAsync` gives it wall-clock time.
    //  * The widget tree needs frames pumped to rebuild once those futures land.
    //
    // `pumpAndSettle` is not used at all: the splash and loading states show an
    // indeterminate progress indicator, which animates forever and would never
    // settle. Instead this pumps until nothing is loading any more, so a large
    // collection being installed gets as long as it needs.
    const int minimumRounds = 25;
    const int maximumRounds = 120;
    for (int i = 0; i < maximumRounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      final bool busy = tester.any(find.byType(LoadingView)) ||
          tester.any(find.byType(SplashScreen));
      if (i >= minimumRounds && !busy) return;
    }
  }
}

/// Runs an action that touches the database, then rebuilds the UI.
///
/// Controller methods await real database I/O. Awaiting them directly from a
/// widget-test body deadlocks, because the fake clock never delivers those
/// completions; `runAsync` runs them against the real event loop instead.
extension HarnessActions on TestHarness {
  Future<T?> act<T>(WidgetTester tester, Future<T> Function() action) async {
    final T? result = await tester.runAsync(action);
    await settle(tester);
    return result;
  }

  /// Scrolls a button into view and taps it.
  ///
  /// The reading and onboarding screens are taller than a test viewport, so a
  /// bare `tap` would silently miss.
  Future<void> tapButton(WidgetTester tester, String label) async {
    // Matched by predicate rather than `byType`: `find.byType` compares exact
    // runtime types, so it would miss FilledButton/OutlinedButton subclasses.
    final Finder finder = find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }
}
