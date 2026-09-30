import 'package:daily_hadith/app/providers.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/reading_progress.dart';
import 'package:daily_hadith/features/today/today_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> randomReader({List<String>? pool}) => <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'a',
        'flutter.pref.reading_order': ReadingOrder.random.storageKey,
        'flutter.pref.random_collection_ids': pool ?? <String>['a', 'b'],
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.time': '08:00',
      };

  Future<TestHarness> start(
    WidgetTester tester, {
    List<String>? pool,
  }) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.books(<String, int>{'a': 5, 'b': 5}),
      initialPreferences: randomReader(pool: pool),
    );
    await harness.pumpApp(tester);
    return harness;
  }

  TodayState today(TestHarness harness) =>
      harness.container.read(todayControllerProvider).value!;

  testWidgets('shows a random hadith from the chosen books',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester);

    final TodayState state = today(harness);
    expect(state.isRandom, isTrue);
    expect(<String>['a', 'b'], contains(state.collection!.id));
    expect(find.text('Random · from 2 books'), findsOneWidget);
    expect(find.text('0 of 10 read'), findsOneWidget);
    // There is no previous or next at random, only another draw.
    expect(find.byTooltip('Previous hadith'), findsNothing);
    expect(find.byTooltip('Show another hadith'), findsOneWidget);
  });

  testWidgets('the hadith holds for the period and changes with the next',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester);
    final String first = today(harness).hadith!.id;

    // Reopening later the same period shows the same hadith.
    harness.clock.advanceHours(3);
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );
    expect(today(harness).hadith!.id, first);

    // The next morning's reminder brings a different one.
    harness.clock.advanceDays(1);
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );
    expect(today(harness).hadith!.id, isNot(first));
  });

  testWidgets('read hadith are not drawn again until all are read',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester);
    final Set<String> seen = <String>{};
    for (int day = 0; day < 10; day++) {
      final String id = today(harness).hadith!.id;
      expect(seen, isNot(contains(id)), reason: 'day $day repeated $id');
      seen.add(id);
      await harness.act(
        tester,
        () => harness.container.read(todayControllerProvider.notifier).markRead(),
      );
      harness.clock.advanceDays(1);
      await harness.act(
        tester,
        () =>
            harness.container.read(todayControllerProvider.notifier).refresh(),
      );
    }
    expect(seen, hasLength(10));
    expect(find.text('10 of 10 read'), findsOneWidget);
  });

  testWidgets('reading at random leaves the book’s own place alone',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester, pool: <String>['a']);
    final int ordinal = today(harness).hadith!.ordinal;

    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).markRead(),
    );

    final ReadingProgress progress = today(harness).progress!;
    expect(progress.totalRead, 1);
    expect(progress.lastReadAt, isNull);
    // Unless the draw happened to be hadith 1, the in-order position is
    // untouched.
    if (ordinal != 1) expect(progress.currentOrdinal, 1);
  });

  testWidgets('show another draws a different hadith for the period',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester);
    final String first = today(harness).hadith!.id;

    // The button sits below the hadith, off a test-sized screen.
    await tester.ensureVisible(find.byTooltip('Show another hadith'));
    await tester.pump();
    await tester.tap(find.byTooltip('Show another hadith'));
    await harness.settle(tester);

    expect(today(harness).hadith!.id, isNot(first));
  });

  testWidgets('the Today toggle switches back to reading in order',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester);

    await tester.tap(find.byTooltip('Read in order'));
    await harness.settle(tester);

    expect(harness.container.read(userPreferencesProvider).isRandom, isFalse);
    expect(find.text('Hadith 1'), findsOneWidget);
    expect(find.text('Random · from 2 books'), findsNothing);
    expect(find.byTooltip('Next hadith'), findsOneWidget);
  });

  testWidgets('changing the books draws again from the new ones',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester, pool: <String>['a']);
    expect(today(harness).collection!.id, 'a');

    await harness.act(
      tester,
      () => harness.container
          .read(userPreferencesProvider.notifier)
          .setRandomPool(<String>['b']),
    );
    await harness.act(
      tester,
      () => harness.container.read(todayControllerProvider.notifier).refresh(),
    );

    expect(today(harness).collection!.id, 'b');
    expect(find.text('Random · from 1 book'), findsOneWidget);
  });

  testWidgets('the settings screen chooses the books',
      (WidgetTester tester) async {
    final TestHarness harness = await start(tester, pool: <String>['a']);
    await harness.goTo(tester, '/settings/reading');

    expect(find.text('BOOKS TO DRAW FROM · 1 BOOK'), findsOneWidget);
    // The last book left cannot be switched off.
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      isNull,
    );
    await tester.tap(find.text('Book b'));
    await harness.settle(tester);

    expect(harness.container.read(userPreferencesProvider).randomPool,
        <String>['a', 'b']);
    expect(find.text('BOOKS TO DRAW FROM · 2 BOOKS'), findsOneWidget);
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      isNotNull,
    );
  });
}
