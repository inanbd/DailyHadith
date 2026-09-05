import 'dart:convert';

import 'package:daily_hadith/core/errors/app_exception.dart';
import 'package:daily_hadith/data/content/asset_hadith_content_source.dart';
import 'package:daily_hadith/data/content/content_schema.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String catalog(List<Map<String, Object?>> collections) => jsonEncode(
        <String, Object?>{
          'schemaVersion': 1,
          'collections': collections,
        },
      );

  const Map<String, Object?> riyad = <String, Object?>{
    'id': 'riyad_as_salihin',
    'slug': 'riyad_as_salihin',
    'titleEnglish': 'Riyad as-Salihin',
    'titleArabic': 'رياض الصالحين',
    'compiler': 'Imam an-Nawawi',
    'description': 'A topical collection.',
    'totalHadith': 3,
    'verification': 'verified',
    'source': <String, Object?>{
      'name': 'Example dataset',
      'url': 'https://example.org/dataset',
      'translator': 'Example translator',
      'licence': 'CC BY 4.0',
      'retrievedAt': '2026-02-01T00:00:00Z',
    },
  };

  String collectionFile() => jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'collectionId': 'riyad_as_salihin',
        'chapters': <Object?>[
          <String, Object?>{
            'chapterNumber': 1,
            'titleEnglish': 'Sincerity',
            'titleArabic': 'الإخلاص',
            'hadithCount': 3,
          },
        ],
        'hadith': <Object?>[
          <String, Object?>{
            'hadithNumber': '1',
            'bookNumber': 1,
            'chapterNumber': 1,
            'arabic': 'النص العربي الأول',
            'english': 'The first English text.',
            'narrator': 'Narrated by someone',
            'grade': 'Sahih',
            'reference': 'Riyad as-Salihin 1',
          },
          <String, Object?>{
            'hadithNumber': '2',
            'arabic': '   ',
            'english': 'Only English here.',
          },
          <String, Object?>{
            'hadithNumber': '3a',
            'arabic': 'النص العربي الثالث',
          },
        ],
      });

  AssetHadithContentSource sourceWith(Map<String, String> assets) =>
      AssetHadithContentSource(bundle: MapAssetBundle(assets));

  test('parses the catalog including source attribution', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
    });

    final List<HadithCollection> collections = await source.loadCatalog();
    expect(collections, hasLength(1));

    final HadithCollection collection = collections.single;
    expect(collection.id, 'riyad_as_salihin');
    expect(collection.titleArabic, 'رياض الصالحين');
    expect(collection.totalHadith, 3);
    expect(collection.verification, ContentVerification.verified);
    expect(collection.source.name, 'Example dataset');
    expect(collection.source.translator, 'Example translator');
    expect(collection.source.licence, 'CC BY 4.0');
    expect(collection.source.retrievedAt, isNotNull);
  });

  test('marks fixture collections as unverified', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[
        <String, Object?>{...riyad, 'verification': 'development_fixture'},
      ]),
    });
    final HadithCollection collection = (await source.loadCatalog()).single;
    expect(collection.isFixture, isTrue);
  });

  test('loads hadith with contiguous ordinals and verbatim text', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
      ContentSchema.assetForSlug('riyad_as_salihin'): collectionFile(),
    });

    final List<Hadith> hadith = await source.loadHadith('riyad_as_salihin');
    expect(hadith.map((Hadith h) => h.ordinal), <int>[1, 2, 3]);
    expect(hadith.first.arabicText, 'النص العربي الأول');
    expect(hadith.first.englishText, 'The first English text.');
    expect(hadith.first.grade, 'Sahih');

    // Whitespace-only fields become null so the reader never sees a blank block.
    expect(hadith[1].hasArabic, isFalse);
    expect(hadith[1].hasEnglish, isTrue);

    // Non-numeric published numbers survive, and the ordinal stays the
    // sequence position.
    expect(hadith[2].hadithNumber, '3a');
    expect(hadith[2].ordinal, 3);
    expect(hadith[2].hasEnglish, isFalse);
  });

  test('falls back to the collection source for per-hadith attribution', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
      ContentSchema.assetForSlug('riyad_as_salihin'): collectionFile(),
    });
    final List<Hadith> hadith = await source.loadHadith('riyad_as_salihin');
    expect(hadith.first.source, 'Example dataset');
  });

  test('reports content as unavailable rather than throwing', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
    });
    expect(await source.hasContentFor('riyad_as_salihin'), isFalse);
    expect(await source.hasContentFor('nonexistent'), isFalse);
    expect(await source.loadChapters('riyad_as_salihin'), isEmpty);
  });

  test('a missing catalog is a catalog failure, not a crash', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{});
    expect(
      () => source.loadCatalog(),
      throwsA(isA<CatalogUnavailableException>()),
    );
  });

  test('malformed catalog JSON is reported cleanly', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: '{not json',
    });
    expect(
      () => source.loadCatalog(),
      throwsA(isA<CatalogUnavailableException>()),
    );
  });

  test('an unknown collection cannot be loaded', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
    });
    expect(
      () => source.loadHadith('nonexistent'),
      throwsA(isA<DatasetUnavailableException>()),
    );
  });

  test('chapters are parsed when present', () async {
    final AssetHadithContentSource source = sourceWith(<String, String>{
      ContentSchema.catalogAsset: catalog(<Map<String, Object?>>[riyad]),
      ContentSchema.assetForSlug('riyad_as_salihin'): collectionFile(),
    });
    final List<dynamic> chapters =
        await source.loadChapters('riyad_as_salihin');
    expect(chapters, hasLength(1));
  });
}
