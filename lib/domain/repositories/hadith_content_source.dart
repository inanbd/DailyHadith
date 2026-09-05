import '../entities/chapter.dart';
import '../entities/hadith.dart';
import '../entities/hadith_collection.dart';

/// The swappable content layer.
///
/// This is the single seam between the app and wherever hadith text comes
/// from. The bundled implementation reads JSON assets; a network-backed or
/// publisher-provided implementation can replace it without any UI change.
///
/// Implementations must reproduce source text verbatim.
abstract interface class HadithContentSource {
  /// Every collection this source knows about, whether or not its text is
  /// available yet.
  Future<List<HadithCollection>> loadCatalog();

  /// True when [collectionId]'s text can be produced by this source.
  Future<bool> hasContentFor(String collectionId);

  /// The full ordered text of a collection, ready to be persisted locally.
  ///
  /// Called once per collection when it is first opened. Ordinals must be
  /// contiguous and 1-based.
  Future<List<Hadith>> loadHadith(String collectionId);

  /// Chapter metadata for a collection. May be empty.
  Future<List<HadithChapter>> loadChapters(String collectionId);
}
