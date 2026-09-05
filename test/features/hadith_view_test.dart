import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/shared/theme/app_theme.dart';
import 'package:daily_hadith/shared/widgets/hadith_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Hadith full = Hadith(
    id: 'c:1',
    collectionId: 'c',
    ordinal: 1,
    hadithNumber: '1',
    arabicText: 'النص العربي',
    englishText: 'The English translation.',
    narrator: 'Narrated by someone',
    grade: 'Sahih',
    reference: 'Test Collection 1',
    chapterEnglish: 'A chapter',
  );

  Future<void> pumpView(
    WidgetTester tester,
    Hadith hadith,
    LanguageMode mode, {
    double scale = 1.0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HadithView(
              hadith: hadith,
              languageMode: mode,
              textScale: scale,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows Arabic above English when both are selected',
      (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.both);

    expect(find.text('النص العربي'), findsOneWidget);
    expect(find.text('The English translation.'), findsOneWidget);

    // Arabic sits above the translation.
    final double arabicY = tester.getTopLeft(find.text('النص العربي')).dy;
    final double englishY =
        tester.getTopLeft(find.text('The English translation.')).dy;
    expect(arabicY, lessThan(englishY));

    // And is separated by the divider.
    expect(find.byType(HadithDivider), findsOneWidget);
  });

  testWidgets('lays Arabic out right-to-left', (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.arabic);

    final Directionality directionality = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.text('النص العربي'),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(directionality.textDirection, TextDirection.rtl);

    final Text arabic = tester.widget<Text>(find.text('النص العربي'));
    expect(arabic.textAlign, TextAlign.right);
    expect(arabic.locale, const Locale('ar'));
  });

  testWidgets('English-only hides the Arabic and the divider',
      (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.english);

    expect(find.text('النص العربي'), findsNothing);
    expect(find.text('The English translation.'), findsOneWidget);
    expect(find.byType(HadithDivider), findsNothing);
  });

  testWidgets('Arabic-only hides the translation', (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.arabic);

    expect(find.text('النص العربي'), findsOneWidget);
    expect(find.text('The English translation.'), findsNothing);
  });

  testWidgets('falls back to the available language when the chosen one is '
      'missing', (WidgetTester tester) async {
    const Hadith englishOnly = Hadith(
      id: 'c:2',
      collectionId: 'c',
      ordinal: 2,
      hadithNumber: '2',
      englishText: 'Only a translation exists.',
    );

    // Asking for Arabic on an entry with none still shows something readable
    // rather than a blank page.
    await pumpView(tester, englishOnly, LanguageMode.arabic);
    expect(find.text('Only a translation exists.'), findsOneWidget);
  });

  testWidgets('renders reference, grading and narrator when present',
      (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.both);

    expect(find.text('Narrated by someone'), findsOneWidget);
    expect(find.text('Test Collection 1'), findsOneWidget);
    expect(find.text('Grading: Sahih'), findsOneWidget);
    expect(find.text('Chapter: A chapter'), findsOneWidget);
  });

  testWidgets('omits the reference block when the source gives nothing',
      (WidgetTester tester) async {
    const Hadith bare = Hadith(
      id: 'c:3',
      collectionId: 'c',
      ordinal: 3,
      hadithNumber: '3',
      englishText: 'Text with no citation.',
    );
    await pumpView(tester, bare, LanguageMode.both);

    expect(find.text('REFERENCE'), findsNothing);
  });

  testWidgets('applies the reader’s text size to both scripts',
      (WidgetTester tester) async {
    await pumpView(tester, full, LanguageMode.both);
    final double baseArabic =
        tester.widget<Text>(find.text('النص العربي')).style!.fontSize!;
    final double baseEnglish = tester
        .widget<Text>(find.text('The English translation.'))
        .style!
        .fontSize!;

    await pumpView(tester, full, LanguageMode.both, scale: 1.3);
    final double largeArabic =
        tester.widget<Text>(find.text('النص العربي')).style!.fontSize!;
    final double largeEnglish = tester
        .widget<Text>(find.text('The English translation.'))
        .style!
        .fontSize!;

    expect(largeArabic, closeTo(baseArabic * 1.3, 0.01));
    expect(largeEnglish, closeTo(baseEnglish * 1.3, 0.01));
  });
}
