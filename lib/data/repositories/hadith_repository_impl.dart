import '../../core/errors/app_exception.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/repositories/hadith_content_source.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../local/hadith_dao.dart';

/// Bridges the content source and local storage.
///
/// The content source is consulted once per collection, at install time;
/// everything the UI reads afterwards comes from SQLite. That is what makes the
/// reading experience work with no network and makes swapping the content
/// source invisible to the rest of the app.
class HadithRepositoryImpl implements HadithRepository {
  HadithRepositoryImpl({required this.contentSource, required this.dao});

  /// Where hadith text comes from. Swapping this changes the data provider for
  /// the whole app.
  final HadithContentSource contentSource;

  /// Local storage the text is copied into.
  final HadithDao dao;

  @override
  Future<List<HadithCollection>> collections() async {
    final List<HadithCollection> catalog = await contentSource.loadCatalog();
    final Set<String> installed = await dao.installedCollectionIds();

    final List<HadithCollection> result = <HadithCollection>[];
    for (final HadithCollection collection in catalog) {
      if (installed.contains(collection.id)) {
        final int count = await dao.countFor(collection.id);
        result.add(
          collection.copyWith(
            isInstalled: true,
            isAvailable: true,
            // Trust what is actually stored over the catalog's stated total, so
            // progress is never measured against a count we do not have.
            totalHadith: count > 0 ? count : collection.totalHadith,
          ),
        );
      } else {
        result.add(
          collection.copyWith(
            isInstalled: false,
            isAvailable: await contentSource.hasContentFor(collection.id),
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<HadithCollection?> collection(String collectionId) async {
    final List<HadithCollection> all = await collections();
    for (final HadithCollection candidate in all) {
      if (candidate.id == collectionId) return candidate;
    }
    return null;
  }

  @override
  Future<HadithCollection> installCollection(
    String collectionId, {
    bool force = false,
  }) async {
    final HadithCollection? catalogEntry = await _catalogEntry(collectionId);
    if (catalogEntry == null) {
      throw DatasetUnavailableException(collectionId);
    }

    if (!force) {
      final int existing = await dao.countFor(collectionId);
      if (existing > 0) {
        return catalogEntry.copyWith(
          isInstalled: true,
          isAvailable: true,
          totalHadith: existing,
        );
      }
    }

    final List<Hadith> hadith = await contentSource.loadHadith(collectionId);
    final List<HadithChapter> chapters =
        await contentSource.loadChapters(collectionId);
    await dao.replaceCollection(
      collectionId,
      catalogEntry.slug,
      hadith,
      chapters,
    );
    return catalogEntry.copyWith(
      isInstalled: true,
      isAvailable: true,
      totalHadith: hadith.length,
    );
  }

  @override
  Future<Hadith?> hadithAt(String collectionId, int ordinal) {
    if (ordinal < 1) return Future<Hadith?>.value();
    return dao.byOrdinal(collectionId, ordinal);
  }

  @override
  Future<Hadith?> hadithById(String hadithId) => dao.byId(hadithId);

  @override
  Future<int> installedCount(String collectionId) => dao.countFor(collectionId);

  @override
  Future<List<HadithChapter>> chapters(String collectionId) =>
      dao.chapters(collectionId);

  @override
  Future<int?> firstOrdinalOfChapter(String collectionId, int chapterNumber) =>
      dao.firstOrdinalOfChapter(collectionId, chapterNumber);

  Future<HadithCollection?> _catalogEntry(String collectionId) async {
    final List<HadithCollection> catalog = await contentSource.loadCatalog();
    for (final HadithCollection collection in catalog) {
      if (collection.id == collectionId) return collection;
    }
    return null;
  }
}
