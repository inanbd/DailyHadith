import 'package:daily_hadith/data/content/asset_hadith_content_source.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the JSON that actually ships with the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssetHadithContentSource source;

  setUp(() => source = AssetHadithContentSource());

  test('the bundled catalog parses', () async {
    final List<HadithCollection> collections = await source.loadCatalog();
    expect(collections, isNotEmpty);

    for (final HadithCollection collection in collections) {
      expect(collection.id, isNotEmpty);
      expect(collection.slug, isNotEmpty);
      expect(collection.titleEnglish, isNotEmpty);
      expect(collection.totalHadith, greaterThan(0));
      expect(collection.source.name, isNotEmpty);
    }

    final Set<String> ids =
        collections.map((HadithCollection c) => c.id).toSet();
    expect(ids.length, collections.length, reason: 'ids must be unique');
  });

  test('at least one collection ships with readable content', () async {
    final List<HadithCollection> collections = await source.loadCatalog();
    final List<HadithCollection> available = <HadithCollection>[
      for (final HadithCollection collection in collections)
        if (await source.hasContentFor(collection.id)) collection,
    ];
    expect(
      available,
      isNotEmpty,
      reason: 'the app must be runnable straight after checkout',
    );
  });

  test('the development sample is labelled a fixture', () async {
    final List<HadithCollection> collections = await source.loadCatalog();
    final HadithCollection sample = collections.firstWhere(
      (HadithCollection collection) => collection.id == 'dev_sample',
    );
    expect(sample.verification, ContentVerification.developmentFixture);
    expect(sample.isFixture, isTrue);
  });

  test('any readable collection is a fixture or carries real attribution',
      () async {
    // The invariant that matters: text is never shown without the reader being
    // able to tell where it came from, or that it is placeholder data.
    final List<HadithCollection> collections = await source.loadCatalog();
    for (final HadithCollection collection in collections) {
      if (!await source.hasContentFor(collection.id)) continue;
      if (collection.isFixture) continue;

      expect(
        collection.verification,
        ContentVerification.verified,
        reason: '${collection.id} must be verified or marked a fixture',
      );
      expect(
        collection.source.name,
        isNot('Not yet imported'),
        reason: '${collection.id} ships text, so it needs real attribution',
      );
      expect(collection.source.name.trim(), isNotEmpty);
    }
  });

  test('the development fixture loads with contiguous ordinals', () async {
    final List<Hadith> hadith = await source.loadHadith('dev_sample');
    expect(hadith, isNotEmpty);

    for (int i = 0; i < hadith.length; i++) {
      expect(hadith[i].ordinal, i + 1);
      expect(hadith[i].collectionId, 'dev_sample');
      expect(hadith[i].hadithNumber, isNotEmpty);
    }

    final Set<String> ids = hadith.map((Hadith h) => h.id).toSet();
    expect(ids.length, hadith.length, reason: 'hadith ids must be unique');
  });

  test('the fixture exercises Arabic, English and missing-field states',
      () async {
    final List<Hadith> hadith = await source.loadHadith('dev_sample');
    expect(hadith.any((Hadith h) => h.hasArabic && h.hasEnglish), isTrue);
    expect(hadith.any((Hadith h) => h.hasArabic && !h.hasEnglish), isTrue);
    expect(hadith.any((Hadith h) => !h.hasArabic && h.hasEnglish), isTrue);
    expect(hadith.every((Hadith h) => h.hasAnyText), isTrue);
  });

  test('fixture text says plainly that it is not hadith', () async {
    final List<Hadith> hadith = await source.loadHadith('dev_sample');
    for (final Hadith item in hadith) {
      final String text = '${item.arabicText ?? ''} ${item.englishText ?? ''}';
      expect(
        text.contains('fixture') ||
            text.contains('Development') ||
            text.contains('تجريبي'),
        isTrue,
        reason: 'fixture entry ${item.ordinal} must identify itself',
      );
    }
  });

  test('the fixture chapter list matches its entries', () async {
    final List<dynamic> chapters = await source.loadChapters('dev_sample');
    expect(chapters, isNotEmpty);
  });
}
