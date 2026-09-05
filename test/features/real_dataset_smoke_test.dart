import 'package:daily_hadith/data/content/asset_hadith_content_source.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the imported Riyad as-Salihin through the real content source.
///
/// Skipped when the dataset has not been imported, so a fresh checkout stays
/// green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Riyad as-Salihin reads end to end when imported', () async {
    final AssetHadithContentSource source = AssetHadithContentSource();
    if (!await source.hasContentFor('riyad_as_salihin')) {
      markTestSkipped('riyad_as_salihin not imported');
      return;
    }

    final List<HadithCollection> catalog = await source.loadCatalog();
    final HadithCollection collection = catalog.firstWhere(
      (HadithCollection c) => c.id == 'riyad_as_salihin',
    );
    expect(collection.titleArabic, 'رياض الصالحين');
    expect(collection.totalHadith, 1896);

    final List<Hadith> hadith = await source.loadHadith('riyad_as_salihin');
    expect(hadith, hasLength(1896));

    // Sequence position and published number line up for this collection.
    final Hadith twentyFour = hadith[23];
    expect(twentyFour.ordinal, 24);
    expect(twentyFour.hadithNumber, '24');
    expect(twentyFour.reference, 'Riyad as-Salihin 24');
    expect(twentyFour.hasArabic, isTrue);
    expect(twentyFour.hasEnglish, isTrue);
    expect(twentyFour.narrator, isNotNull);
    expect(twentyFour.chapterEnglish, isNotNull);

    // Spot-check the start, middle and end, as the import checklist advises.
    for (final int index in <int>[0, 947, 1895]) {
      expect(hadith[index].hasArabic, isTrue, reason: 'entry ${index + 1}');
      expect(hadith[index].hasEnglish, isTrue, reason: 'entry ${index + 1}');
    }

    expect(await source.loadChapters('riyad_as_salihin'), hasLength(20));
  });
}
