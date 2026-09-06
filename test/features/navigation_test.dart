import 'package:daily_hadith/app/routes.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/features/favourites/favourites_screen.dart';
import 'package:daily_hadith/features/library/collection_details_screen.dart';
import 'package:daily_hadith/features/library/library_screen.dart';
import 'package:daily_hadith/features/progress/progress_screen.dart';
import 'package:daily_hadith/features/settings/about_screen.dart';
import 'package:daily_hadith/features/settings/appearance_settings_screen.dart';
import 'package:daily_hadith/features/settings/language_settings_screen.dart';
import 'package:daily_hadith/features/settings/notification_settings_screen.dart';
import 'package:daily_hadith/features/settings/settings_screen.dart';
import 'package:daily_hadith/features/today/today_screen.dart';
import 'package:daily_hadith/shared/widgets/hadith_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Every screen must render, in both themes and at the largest text size,
/// without layout errors — a widget test fails on any overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> onboarded({
    String textSize = 'standard',
    String theme = 'system',
  }) =>
      <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'test_collection',
        'flutter.pref.text_size': textSize,
        'flutter.pref.theme_mode': theme,
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.time': '08:00',
      };

  Future<void> go(WidgetTester tester, TestHarness harness, String location) async {
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    context.go(location);
    await harness.settle(tester);
  }

  testWidgets('every tab and settings screen renders', (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    expect(find.byType(TodayScreen), findsOneWidget);

    await go(tester, harness, Routes.library);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Hadith Library'), findsOneWidget);

    await go(tester, harness, Routes.collection('test_collection'));
    expect(find.byType(CollectionDetailsScreen), findsOneWidget);
    expect(find.text('SOURCE'), findsOneWidget);

    await go(tester, harness, Routes.favourites);
    expect(find.byType(FavouritesScreen), findsOneWidget);

    await go(tester, harness, Routes.progress);
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('Your Progress'), findsOneWidget);

    await go(tester, harness, Routes.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await go(tester, harness, Routes.settingsNotifications);
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(find.text('NEXT REMINDERS'), findsOneWidget);

    await go(tester, harness, Routes.settingsLanguage);
    expect(find.byType(LanguageSettingsScreen), findsOneWidget);

    await go(tester, harness, Routes.settingsAppearance);
    expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);

    await go(tester, harness, Routes.settingsAbout);
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('PRIVACY'), findsOneWidget);
  });

  testWidgets('the bottom navigation bar moves between tabs',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    await tester.tap(find.text('Library'));
    await harness.settle(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.tap(find.text('Favourites'));
    await harness.settle(tester);
    expect(find.byType(FavouritesScreen), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await harness.settle(tester);
    expect(find.byType(ProgressScreen), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await harness.settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Today'));
    await harness.settle(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('renders in dark mode at the largest text size',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(textSize: 'extra_large', theme: 'dark'),
    );
    await harness.pumpApp(tester);

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('Hadith 1'), findsOneWidget);

    await go(tester, harness, Routes.library);
    expect(find.byType(LibraryScreen), findsOneWidget);

    await go(tester, harness, Routes.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('renders on a small screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('the development fixture is flagged wherever it is shown',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: FakeContentSource.single(
        id: 'fixture_book',
        title: 'Fixture Book',
        verification: ContentVerification.developmentFixture,
      ),
      initialPreferences: <String, Object>{
        ...onboarded(),
        'flutter.pref.current_collection_id': 'fixture_book',
      },
    );
    await harness.pumpApp(tester);

    expect(find.text('Development data'), findsOneWidget);
    expect(
      find.textContaining('not hadith'),
      findsWidgets,
      reason: 'placeholder content must say so on the reading screen',
    );

    await go(tester, harness, Routes.library);
    expect(find.text('Development data'), findsWidgets);
  });

  testWidgets('swiping turns the page, the way a book does',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    expect(find.text('Hadith 1'), findsOneWidget);

    // Swiping right at the start of the book has nowhere to go.
    await tester.fling(find.byType(HadithView), const Offset(400, 0), 1200);
    await harness.settle(tester);
    expect(find.text('Hadith 1'), findsOneWidget);

    // Left carries the reader forward.
    await tester.fling(find.byType(HadithView), const Offset(-400, 0), 1200);
    await harness.settle(tester);
    expect(find.text('Hadith 2'), findsOneWidget);

    // Right takes them back.
    await tester.fling(find.byType(HadithView), const Offset(400, 0), 1200);
    await harness.settle(tester);
    expect(find.text('Hadith 1'), findsOneWidget);
  });

  testWidgets('a slow horizontal drag while reading does not turn the page',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    // Far enough to move a page, but far too slow to be a flick.
    await tester.timedDrag(
      find.byType(HadithView),
      const Offset(-400, 0),
      const Duration(seconds: 4),
    );
    await harness.settle(tester);

    expect(find.text('Hadith 1'), findsOneWidget);
  });
}
