import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> onboarded() => <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'test_collection',
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.time': '08:00',
      };

  Future<void> tapAction(
    WidgetTester tester,
    TestHarness harness,
    String tooltip,
  ) async {
    final Finder finder = find.byTooltip(tooltip).first;
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(finder);
    });
    await harness.settle(tester);
  }

  testWidgets('pressing listen speaks the translation',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer();
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Listen to the translation');

    expect(speech.spoken, hasLength(1));
    // The English translation is what is read aloud, never the Arabic.
    expect(speech.spoken.single, contains('English'));
    expect(speech.languages.single, 'en-US');
  });

  testWidgets('no listen button when the device has no English voice',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech =
        FakeSpeechSynthesizer(available: false);
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    expect(find.byTooltip('Listen to the translation'), findsNothing);
    // The favourite control is unaffected by a missing voice.
    expect(find.byTooltip('Save to favourites'), findsOneWidget);
  });

  testWidgets('while speaking the button offers to stop',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech =
        FakeSpeechSynthesizer(completeManually: true);
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Listen to the translation');

    expect(find.byTooltip('Stop reading aloud'), findsOneWidget);
    expect(find.byTooltip('Listen to the translation'), findsNothing);

    await tapAction(tester, harness, 'Stop reading aloud');

    expect(speech.stopCalls, greaterThan(0));
    expect(find.byTooltip('Listen to the translation'), findsOneWidget);
  });

  testWidgets('moving to another hadith speaks that one',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer();
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Listen to the translation');
    await tapAction(tester, harness, 'Next hadith');
    await tapAction(tester, harness, 'Listen to the translation');

    expect(speech.spoken, hasLength(2));
    expect(speech.spoken.first, isNot(speech.spoken.last));
  });

  testWidgets('pressing listen beside the Arabic speaks the Arabic',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer();
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Listen to the Arabic');

    expect(speech.spoken, hasLength(1));
    // The Arabic is read in Arabic — not the translation, and not in English.
    expect(speech.spoken.single, contains('عربي'));
    expect(speech.languages.single, 'ar-SA');
  });

  testWidgets('no Arabic button when the device has no Arabic voice',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer(
      unavailableLanguages: <String>{'ar-SA'},
    );
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    expect(find.byTooltip('Listen to the Arabic'), findsNothing);
    // The translation is unaffected by a missing Arabic voice.
    expect(find.byTooltip('Listen to the translation'), findsOneWidget);
  });

  testWidgets('only the control that started an utterance offers to stop it',
      (WidgetTester tester) async {
    final FakeSpeechSynthesizer speech =
        FakeSpeechSynthesizer(completeManually: true);
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
      speech: speech,
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Listen to the Arabic');

    // The Arabic control switched to stop; the translation's did not.
    expect(find.byTooltip('Stop reading aloud'), findsOneWidget);
    expect(find.byTooltip('Listen to the Arabic'), findsNothing);
    expect(find.byTooltip('Listen to the translation'), findsOneWidget);

    // Asking for the translation while the Arabic is speaking switches to it
    // rather than stopping — the reader asked for something different.
    await tapAction(tester, harness, 'Listen to the translation');

    expect(speech.languages, <String>['ar-SA', 'en-US']);
    expect(find.byTooltip('Listen to the Arabic'), findsOneWidget);
  });
}
