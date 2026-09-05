import 'package:daily_hadith/app/routes.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/features/favourites/favourites_screen.dart';
import 'package:daily_hadith/shared/widgets/hadith_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> go(
    WidgetTester tester,
    TestHarness harness,
    String location,
  ) async {
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    context.go(location);
    await harness.settle(tester);
  }

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

  testWidgets('the favourites tab starts empty', (WidgetTester tester) async {
    final TestHarness harness =
        await TestHarness.create(initialPreferences: onboarded());
    await harness.pumpApp(tester);

    await go(tester, harness, Routes.favourites);

    expect(find.byType(FavouritesScreen), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('a hadith saved from Today shows up under Favourites',
      (WidgetTester tester) async {
    final TestHarness harness =
        await TestHarness.create(initialPreferences: onboarded());
    await harness.pumpApp(tester);

    // The heart on today's hadith starts empty, then fills once tapped.
    expect(find.byTooltip('Save to favourites'), findsOneWidget);
    await tapAction(tester, harness, 'Save to favourites');
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);

    await go(tester, harness, Routes.favourites);

    expect(find.text('No favourites yet'), findsNothing);
    expect(find.text('1 saved hadith'), findsOneWidget);
    expect(find.byType(HadithView), findsOneWidget);
  });

  testWidgets('unsaving from the favourites list empties it',
      (WidgetTester tester) async {
    final TestHarness harness =
        await TestHarness.create(initialPreferences: onboarded());
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Save to favourites');
    await go(tester, harness, Routes.favourites);
    expect(find.text('1 saved hadith'), findsOneWidget);

    // The heart is already filled here, so tapping it removes the entry.
    await tapAction(tester, harness, 'Remove from favourites');

    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('favourites are kept per hadith, not per book',
      (WidgetTester tester) async {
    final TestHarness harness =
        await TestHarness.create(initialPreferences: onboarded());
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Save to favourites');
    // Move to the next hadith: its heart must be empty again.
    await tapAction(tester, harness, 'Next hadith');
    expect(find.byTooltip('Save to favourites'), findsOneWidget);

    await tapAction(tester, harness, 'Save to favourites');
    await go(tester, harness, Routes.favourites);

    expect(find.text('2 saved hadith'), findsOneWidget);
  });

  testWidgets('the five-tab bar and favourites render at the largest text size',
      (WidgetTester tester) async {
    // Five destinations is the point where the navigation bar is most likely
    // to overflow, so this checks the widest labels at the biggest type.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final TestHarness harness = await TestHarness.create(
      initialPreferences: <String, Object>{
        ...onboarded(),
        'flutter.pref.text_size': 'extra_large',
        'flutter.pref.theme_mode': 'dark',
      },
    );
    await harness.pumpApp(tester);

    await tapAction(tester, harness, 'Save to favourites');
    await go(tester, harness, Routes.favourites);

    expect(find.byType(FavouritesScreen), findsOneWidget);
    expect(find.text('1 saved hadith'), findsOneWidget);
  });
}
