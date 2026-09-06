import 'package:daily_hadith/domain/entities/chapter.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// Chapter browsing is optional: it appears only for books whose dataset
/// actually carried chapters, and it never appears on the reading surface
/// uninvited.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object> onboarded() => <String, Object>{
        'flutter.pref.onboarding_complete': true,
        'flutter.pref.current_collection_id': 'test_collection',
        'flutter.notify.enabled': true,
        'flutter.notify.frequency': NotificationFrequency.daily.storageKey,
        'flutter.notify.time': '08:00',
      };

  /// Ten hadith split into two chapters: 1–5 and 6–10.
  FakeContentSource withChapters() {
    final FakeContentSource base = FakeContentSource.single(count: 10);
    return FakeContentSource(
      collections: base.collections,
      hadithByCollection: <String, List<Hadith>>{
        'test_collection': <Hadith>[
          for (int i = 1; i <= 10; i++)
            Hadith(
              id: 'test_collection:$i',
              collectionId: 'test_collection',
              ordinal: i,
              hadithNumber: '$i',
              // The second half of the book belongs to the second chapter.
              chapterNumber: i <= 5 ? 1 : 2,
              chapterEnglish: i <= 5 ? 'Chapter one' : 'Chapter two',
              arabicText: 'نص عربي رقم $i',
              englishText: 'English text number $i.',
              narrator: 'Test narrator',
              reference: 'Test Collection $i',
            ),
        ],
      },
      chaptersByCollection: <String, List<HadithChapter>>{
        'test_collection': <HadithChapter>[
          const HadithChapter(
            collectionId: 'test_collection',
            chapterNumber: 1,
            titleEnglish: 'The Book of Openings',
            titleArabic: 'كتاب الفواتح',
            hadithCount: 5,
          ),
          const HadithChapter(
            collectionId: 'test_collection',
            chapterNumber: 2,
            titleEnglish: 'The Book of Endings',
            titleArabic: 'كتاب الخواتم',
            hadithCount: 5,
          ),
        ],
      },
    );
  }

  testWidgets('a book with no chapter data offers no chapters control',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    expect(find.byTooltip('Chapters'), findsNothing);
  });

  testWidgets('chapters stay behind an icon rather than on the page',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: withChapters(),
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    // Offered, but not shown: the reading surface is unchanged.
    expect(find.byTooltip('Chapters'), findsOneWidget);
    expect(find.text('The Book of Endings'), findsNothing);
  });

  testWidgets('opening a chapter moves the reader to its first hadith',
      (WidgetTester tester) async {
    final TestHarness harness = await TestHarness.create(
      contentSource: withChapters(),
      initialPreferences: onboarded(),
    );
    await harness.pumpApp(tester);

    expect(find.text('Hadith 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Chapters'));
    await harness.settle(tester);
    expect(find.text('The Book of Openings'), findsOneWidget);
    expect(find.text('The Book of Endings'), findsOneWidget);

    await tester.tap(find.text('The Book of Endings'));
    await harness.settle(tester);

    // The sheet closes and the reader is at the start of that chapter.
    expect(find.text('The Book of Endings'), findsNothing);
    expect(find.text('Hadith 6'), findsOneWidget);
    // Jumping is browsing, not reading: nothing was marked on the way.
    expect(find.text('0 of 10 read'), findsOneWidget);
  });
}
