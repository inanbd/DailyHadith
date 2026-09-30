import 'package:daily_hadith/app/providers.dart';
import 'package:daily_hadith/app/routes.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/repositories/notification_scheduler.dart';
import 'package:daily_hadith/features/today/today_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> reader({
    bool preview = true,
    ReadingOrder order = ReadingOrder.sequential,
    List<String> times = const <String>['08:00'],
  }) =>
      <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'test_collection',
        'flutter.pref.reading_order': order.storageKey,
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.times': times,
        'flutter.notify.show_preview': preview,
      };

  testWidgets('in order, each reminder carries the next unread hadith',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(),
    );
    await harness.pumpApp(tester);

    // Hadith 1 is on screen for today, so tomorrow's reminder brings 2.
    expect(find.text('Hadith 1'), findsOneWidget);
    final List<PlannedReminder> plan = scheduler.scheduledPlans.last;
    expect(plan.first.at, DateTime(2026, 1, 8, 8, 0));
    expect(plan.first.title, 'Test Collection · Hadith 2');
    expect(plan.first.body, 'English text number 2.');
    expect(
      plan.first.link,
      const HadithDeepLink(collectionId: 'test_collection', ordinal: 2),
    );
    expect(
      plan.take(3).map((PlannedReminder r) => r.link.ordinal),
      <int>[2, 3, 4],
    );
    // Past the end of the book the reminders still come, as invitations.
    expect(plan[9].link.ordinal, isNull);
    expect(plan[9].title, 'Today’s Hadith');
  });

  testWidgets('marking a hadith re-plans what the reminders carry',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(),
    );
    await harness.pumpApp(tester);

    // Read ahead: hadith 2 now needs no reminder.
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).goTo(2),
    );
    final int before = scheduler.scheduledPlans.length;
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).markRead(),
    );

    expect(scheduler.scheduledPlans.length, greaterThan(before));
    expect(
      scheduler.scheduledPlans.last
          .take(3)
          .map((PlannedReminder r) => r.link.ordinal),
      <int>[1, 3, 4],
    );
  });

  testWidgets('with previews off, reminders are plain invitations',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(preview: false),
    );
    await harness.pumpApp(tester);

    expect(scheduler.scheduledPreferences.last.showHadithPreview, isFalse);
    expect(scheduler.scheduledPlans.last, isEmpty);
  });

  testWidgets('the preview switch in settings turns previews off',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(),
    );
    await harness.pumpApp(tester);
    await harness.goTo(tester, Routes.settingsNotifications);

    final Finder row = find.text('Show the hadith in the reminder');
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: row, matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      ),
    );
    await harness.settle(tester);

    expect(scheduler.scheduledPreferences.last.showHadithPreview, isFalse);
    expect(scheduler.scheduledPlans.last, isEmpty);
  });

  testWidgets('at random, a reminder carries the hadith its period will show',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.books(<String, int>{'a': 6, 'b': 6}),
      scheduler: scheduler,
      initialPreferences: <String, Object>{
        ...reader(order: ReadingOrder.random),
        'flutter.pref.current_collection_id': 'a',
        'flutter.pref.random_collection_ids': <String>['a', 'b'],
      },
    );
    await harness.pumpApp(tester);

    final HadithDeepLink onScreen = HadithDeepLink(
      collectionId: harness.container
          .read(todayControllerProvider)
          .value!
          .collection!
          .id,
      ordinal:
          harness.container.read(todayControllerProvider).value!.hadith!.ordinal,
    );
    final PlannedReminder next = scheduler.scheduledPlans.last.first;
    // Never the one already on screen.
    expect(next.link, isNot(onScreen));

    // When that reminder's time comes, the app shows what it previewed.
    harness.clock.now = next.at.add(const Duration(minutes: 1));
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );
    final TodayState state = harness.container.read(todayControllerProvider).value!;
    expect(
      HadithDeepLink(
        collectionId: state.collection!.id,
        ordinal: state.hadith!.ordinal,
      ),
      next.link,
    );
  });

  testWidgets('tapping a reminder opens exactly the hadith it showed',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler(
      launchDeepLink:
          const HadithDeepLink(collectionId: 'test_collection', ordinal: 4),
    );
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(),
    );
    await harness.pumpApp(tester);
    await harness.settle(tester);

    expect(find.text('Hadith 4'), findsOneWidget);
    expect(find.text('1 of 10 read'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Read'), findsOneWidget);
    // Skipped hadith stay unread: the book returns to them next period.
    expect(
      await tester.runAsync(
        () => harness.container
            .read(progressRepositoryProvider)
            .firstUnreadOrdinal('test_collection', 10),
      ),
      1,
    );
  });

  testWidgets('several reminder times each bring a hadith',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(times: <String>['08:00', '18:00']),
    );
    await harness.pumpApp(tester);

    final List<PlannedReminder> plan = scheduler.scheduledPlans.last;
    expect(plan.take(3).map((PlannedReminder r) => r.at), <DateTime>[
      DateTime(2026, 1, 7, 18, 0),
      DateTime(2026, 1, 8, 8, 0),
      DateTime(2026, 1, 8, 18, 0),
    ]);
    expect(
      plan.take(3).map((PlannedReminder r) => r.link.ordinal),
      <int>[2, 3, 4],
    );

    // The evening reminder starts a new reading period.
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).markRead(),
    );
    harness.clock.now = DateTime(2026, 1, 7, 18, 5);
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );
    expect(find.text('Hadith 2'), findsOneWidget);
  });

  testWidgets('settings add and remove reminder times',
      (WidgetTester tester) async {
    final FakeNotificationScheduler scheduler = FakeNotificationScheduler();
    final TestHarness harness = await TestHarness.create(
      scheduler: scheduler,
      initialPreferences: reader(times: <String>['08:00', '18:00']),
    );
    await harness.pumpApp(tester);
    await harness.goTo(tester, Routes.settingsNotifications);

    expect(find.text('Reminder 1'), findsOneWidget);
    expect(find.text('Reminder 2'), findsOneWidget);
    expect(find.text('Each reminder brings a new hadith.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Remove 6:00 PM'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove 6:00 PM'));
    await harness.settle(tester);

    expect(scheduler.scheduledPreferences.last.times,
        const <TimeOfDayValue>[TimeOfDayValue(8, 0)]);
    expect(find.text('Reminder time'), findsOneWidget);
    // The last time left cannot be removed.
    expect(find.byTooltip('Remove 8:00 AM'), findsNothing);
    expect(find.text('Add another time'), findsOneWidget);
  });
}
