/// The JSON contract between the app and whatever produces hadith text.
///
/// Anything that can emit these two shapes — a bundled asset, an HTTP API, a
/// publisher's export — can back the app without a single UI change. The
/// importer in `tool/import_hadith.dart` writes exactly this format.
abstract final class ContentSchema {
  /// Bumped whenever the on-disk shape changes incompatibly.
  static const int version = 1;

  /// Asset path of the collection catalog.
  static const String catalogAsset = 'assets/data/catalog.json';

  /// Directory holding one JSON file per collection.
  static const String collectionsDirectory = 'assets/data/collections';

  static String assetForSlug(String slug) => '$collectionsDirectory/$slug.json';
}
