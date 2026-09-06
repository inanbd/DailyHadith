import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Reading a hadith through and staying with it is what marks it read, so the
/// reader never has to press a button to record something they just did.
///
/// The guard rails matter as much as the behaviour: this must never mark
/// something the reader did not read, and must never overrule them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> onboarded() => <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'test_collection',
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.time': '08:00',
      };

  /// Lets the dwell timer elapse, then settles the database work it starts.
  Future<void> dwell(WidgetTester tester, TestHarness harness) async {
    await tester.pump(TodayScreen.dwell + const Duration(seconds: 1));
    await harness.settle(tester);
  }

  testWidgets('a hadith read through and stayed with marks itself read',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    expect(find.text('0 of 10 read'), findsOneWidget);

    await dwell(tester, harness);

    expect(find.text('1 of 10 read'), findsOneWidget);
    // Still on the hadith that was read — marking never moves the reader on.
    expect(find.text('Hadith 1'), findsOneWidget);
  });

  testWidgets('leaving before the dwell is up marks nothing',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    // Straight past it, the way someone flicking through would.
    final Finder next = find.byTooltip('Next hadith');
    await tester.ensureVisible(next);
    await tester.pump();
    await tester.tap(next);
    await harness.settle(tester);

    expect(find.text('Hadith 2'), findsOneWidget);
    expect(find.text('0 of 10 read'), findsOneWidget);
  });

  testWidgets('a hadith too long to fit is not marked until it is read through',
      (WidgetTester tester) async {
    // Long enough to overflow the viewport, so the end has to be scrolled to.
    final FakeContentSource content = FakeContentSource.single(
      count: 3,
      englishText: (int ordinal) =>
          List<String>.filled(60, 'A long sentence of translation $ordinal.')
              .join(' '),
    );
    final TestHarness harness = await TestHarness.create(
      contentSource: content,
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    // Sitting at the top with most of it unseen marks nothing, however long
    // the reader waits.
    await dwell(tester, harness);
    expect(find.text('0 of 3 read'), findsOneWidget);

    // Reading through to the end does.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -4000),
    );
    await harness.settle(tester);
    await dwell(tester, harness);

    expect(find.text('1 of 3 read'), findsOneWidget);
  });

  testWidgets('marking it back as unread is not overruled',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    await dwell(tester, harness);
    expect(find.text('1 of 10 read'), findsOneWidget);

    // The reader disagrees.
    await harness.tapButton(tester, 'Read');
    expect(find.text('0 of 10 read'), findsOneWidget);

    // Staying on it must not put it straight back.
    await dwell(tester, harness);
    expect(find.text('0 of 10 read'), findsOneWidget);
  });

  testWidgets('a marked hadith stays put instead of marching through the book',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    // Several dwell periods pass with the reader doing nothing at all.
    for (int i = 0; i < 4; i++) {
      await dwell(tester, harness);
    }

    // Reading one hadith marks one hadith. The book must not walk itself
    // forward, marking things nobody ever saw.
    expect(find.text('Hadith 1'), findsOneWidget);
    expect(find.text('1 of 10 read'), findsOneWidget);
  });
}
