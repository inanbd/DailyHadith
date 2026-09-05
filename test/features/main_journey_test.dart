import 'package:daily_hadith/app/providers.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/entities/reading_progress.dart';
import 'package:daily_hadith/domain/repositories/notification_scheduler.dart';
import 'package:daily_hadith/features/today/today_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// The journey the whole product is built around:
///
/// install → choose a book → choose a reminder → read hadith 1 → next morning
/// the reminder arrives → tap it → hadith 2 → progress reads 2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a first-time reader gets set up and reads in sequence',
      (WidgetTester tester) async {
    final FakeContentSource content = FakeContentSource.single(
      id: 'riyad_as_salihin',
      title: 'Riyad as-Salihin',
      count: 1896,
    );
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler(
      status: NotificationPermissionStatus.notDetermined,
    );
    final TestHarness harness = await TestHarness.create(
      contentSource: content,
      scheduler: scheduler,
      now: DateTime(2026, 1, 7, 9, 0),
    );

    await harness.pumpApp(tester);

    // ---- Onboarding step 1 -------------------------------------------------
    expect(find.text('A Hadith at a time'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await harness.tapButton(tester, 'Continue');

    // ---- Step 2: choose the book ------------------------------------------
    expect(find.text('Choose your book'), findsOneWidget);
    expect(find.text('Riyad as-Salihin'), findsOneWidget);
    await harness.tapButton(tester, 'Continue');

    // ---- Step 3: reminder, defaulting to 8:00 AM ---------------------------
    expect(find.text('Choose your reminder'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('English + Arabic'), findsOneWidget);

    // No OS prompt has been raised yet — permission is asked for at the end.
    expect(scheduler.permissionRequests, 0);

    await harness.tapButton(tester, 'Start reading');

    // Permission was requested once, after the reader chose their time.
    expect(scheduler.permissionRequests, 1);

    // Reminders were armed for the chosen book at the chosen time.
    expect(scheduler.scheduledPreferences, isNotEmpty);
    final NotificationPreferences armed = scheduler.scheduledPreferences.last;
    expect(armed.enabled, isTrue);
    expect(armed.frequency, NotificationFrequency.daily);
    expect(armed.time, const TimeOfDayValue(8, 0));
    expect(scheduler.scheduledCollectionIds.last, 'riyad_as_salihin');

    // ---- Day 1: hadith 1 ---------------------------------------------------
    expect(find.text('Today’s Hadith'), findsOneWidget);
    expect(find.text('Hadith 1'), findsOneWidget);
    expect(find.text('English text number 1.'), findsOneWidget);
    expect(find.text('نص عربي رقم 1'), findsOneWidget);
    expect(find.text('0 of 1,896 read'), findsOneWidget);

    await harness.tapButton(tester, 'Mark as read');

    expect(find.text('1 of 1,896 read'), findsOneWidget);
    // Still showing what was just read, not jumping ahead.
    expect(find.text('Hadith 1'), findsOneWidget);

    // ---- Next morning: the reminder fires and is tapped --------------------
    harness.clock.advanceDays(1);

    // The reminder firing on its own changes nothing.
    expect(
      harness.container
          .read(todayControllerProvider)
          .value
          ?.progress
          ?.totalRead,
      1,
    );

    // Tapping it opens the app at the reader's current position.
    await harness.act(
      tester,
      () => harness.container
          .read(todayControllerProvider.notifier)
          .markReadFromNotification(),
    );

    expect(find.text('Hadith 2'), findsOneWidget);
    expect(find.text('English text number 2.'), findsOneWidget);
    expect(find.text('2 of 1,896 read'), findsOneWidget);

    // ---- Day 3 continues the sequence -------------------------------------
    harness.clock.advanceDays(1);
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );

    expect(find.text('Hadith 3'), findsOneWidget);
    expect(find.text('2 of 1,896 read'), findsOneWidget);
  });

  testWidgets('missing several days resumes at the first unread hadith',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.single(count: 50),
      now: DateTime(2026, 1, 7, 9, 0),
      initialPreferences: _onboardedPreferences(),
    );
    await harness.pumpApp(tester);

    expect(find.text('Hadith 1'), findsOneWidget);
    await harness.tapButton(tester, 'Mark as read');

    // Two weeks pass with the app unopened.
    harness.clock.advanceDays(14);
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );

    // Nothing was auto-marked; reading resumes at hadith 2.
    expect(find.text('Hadith 2'), findsOneWidget);
    expect(find.text('1 of 50 read'), findsOneWidget);
  });

  testWidgets('skipping ahead does not mark the hadith passed over',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.single(count: 50),
      now: DateTime(2026, 1, 7, 9, 0),
      initialPreferences: _onboardedPreferences(),
    );
    await harness.pumpApp(tester);

    final TodayController controller =
        harness.container.read(todayControllerProvider.notifier);

    await harness.act(tester, controller.goToNext);
    await harness.act(tester, controller.goToNext);

    expect(find.text('Hadith 3'), findsOneWidget);
    expect(find.text('0 of 50 read'), findsOneWidget);

    await harness.tapButton(tester, 'Mark as read');
    expect(find.text('1 of 50 read'), findsOneWidget);

    // Tomorrow picks up hadith 1, which was never read.
    harness.clock.advanceDays(1);
    await harness.act(tester, controller.refresh);
    expect(find.text('Hadith 1'), findsOneWidget);
  });

  testWidgets('finishing a book shows the completion state',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.single(count: 3, title: 'Short Book'),
      now: DateTime(2026, 1, 7, 9, 0),
      initialPreferences: _onboardedPreferences(),
    );
    await harness.pumpApp(tester);

    final TodayController controller =
        harness.container.read(todayControllerProvider.notifier);
    for (int i = 1; i <= 3; i++) {
      await harness.act(tester, () => controller.goTo(i));
      await harness.act(tester, controller.markRead);
    }

    expect(find.text('Alhamdulillah'), findsOneWidget);
    expect(find.text('You completed Short Book.'), findsOneWidget);
    expect(find.text('3 hadith read.'), findsOneWidget);

    // Reading again clears progress and returns to the first hadith.
    await harness.tapButton(tester, 'Read again from the beginning');

    expect(find.text('Hadith 1'), findsOneWidget);
    expect(find.text('0 of 3 read'), findsOneWidget);
  });

  testWidgets('switching books preserves the first book’s progress',
      (WidgetTester tester) async {
    final FakeContentSource content = FakeContentSource(
      collections: <dynamic>[
        ...FakeContentSource.single(id: 'book_a', title: 'Book A', count: 10)
            .collections,
        ...FakeContentSource.single(id: 'book_b', title: 'Book B', count: 10)
            .collections,
      ].cast(),
      hadithByCollection: <String, dynamic>{
        ...FakeContentSource.single(id: 'book_a', count: 10)
            .hadithByCollection,
        ...FakeContentSource.single(id: 'book_b', count: 10)
            .hadithByCollection,
      }.cast(),
    );

    final TestHarness harness = await TestHarness.create(
      contentSource: content,
      now: DateTime(2026, 1, 7, 9, 0),
      initialPreferences: _onboardedPreferences(collectionId: 'book_a'),
    );
    await harness.pumpApp(tester);

    final TodayController controller =
        harness.container.read(todayControllerProvider.notifier);
    await harness.act(tester, () => controller.goTo(4));
    await harness.act(tester, controller.markRead);
    expect(find.text('1 of 10 read'), findsOneWidget);

    // Switch to book B.
    await harness.act(
      tester,
      () => harness.container
          .read(userPreferencesProvider.notifier)
          .setCurrentCollection('book_b'),
    );
    expect(find.text('0 of 10 read'), findsOneWidget);

    // Switch back: book A is exactly where it was left.
    await harness.act(
      tester,
      () => harness.container
          .read(userPreferencesProvider.notifier)
          .setCurrentCollection('book_a'),
    );

    final ReadingProgress? progress =
        harness.container.read(todayControllerProvider).value?.progress;
    expect(progress?.totalRead, 1);
    expect(progress?.currentOrdinal, 4);
  });
}

/// Preferences for a reader who has already been through onboarding.
Map<String, Object> _onboardedPreferences({
  String collectionId = 'test_collection',
}) {
  return <String, Object>{
    'flutter.pref.onboarding_complete': true,
    'flutter.pref.current_collection_id': collectionId,
    'flutter.pref.language_mode': LanguageMode.both.storageKey,
    'flutter.notify.enabled': true,
    'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
    'flutter.notify.time': '08:00',
  };
}
