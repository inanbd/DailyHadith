import '../entities/chapter.dart';
import '../entities/hadith.dart';
import '../entities/hadith_collection.dart';

/// Reads hadith for the UI, backed by local storage so everything works
/// offline once a collection has been installed.
abstract interface class HadithRepository {
  /// All known collections, with `isInstalled` reflecting local storage.
  Future<List<HadithCollection>> collections();

  Future<HadithCollection?> collection(String collectionId);

  /// Copies a collection's text from the content source into local storage.
  /// Safe to call repeatedly; already-installed collections are a no-op unless
  /// [force] is set.
  Future<HadithCollection> installCollection(
    String collectionId, {
    bool force = false,
  });

  /// The hadith at a 1-based reading position, or null when out of range.
  Future<Hadith?> hadithAt(String collectionId, int ordinal);

  Future<Hadith?> hadithById(String hadithId);

  /// How many hadith are stored locally for a collection.
  Future<int> installedCount(String collectionId);

  Future<List<HadithChapter>> chapters(String collectionId);

  /// The reading position of the first hadith in a chapter, or null when
  /// nothing is stored against it.
  Future<int?> firstOrdinalOfChapter(String collectionId, int chapterNumber);
}
