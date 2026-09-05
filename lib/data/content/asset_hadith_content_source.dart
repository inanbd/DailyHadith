import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/repositories/hadith_content_source.dart';
import '../models/collection_dto.dart';
import '../models/hadith_dto.dart';
import 'content_schema.dart';

/// Reads hadith content from JSON bundled with the app.
///
/// A collection is "available" when its asset is present. The catalog can list
/// books whose data has not been imported yet; those simply report `false` from
/// [hasContentFor] and the UI shows a dataset-not-installed state instead of
/// failing. Dropping an importer-generated file into
/// `assets/data/collections/` is all it takes to light one up.
class AssetHadithContentSource implements HadithContentSource {
  AssetHadithContentSource({this.bundle});

  /// Overrides the bundle assets are read from. Tests inject one; production
  /// leaves it null and reads from the app's root bundle.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  /// Only the catalog is memoised. Collection files are megabytes once parsed
  /// and are needed only while a book is being installed, so holding one for
  /// the life of the app would be pure waste.
  List<HadithCollection>? _catalogCache;

  @override
  Future<List<HadithCollection>> loadCatalog() async {
    final List<HadithCollection>? cached = _catalogCache;
    if (cached != null) return cached;

    final Map<String, Object?> json;
    try {
      json = await _readJson(ContentSchema.catalogAsset);
    } on ContentFormatException catch (error) {
      throw CatalogUnavailableException(cause: error);
    } on Object catch (error) {
      throw CatalogUnavailableException(cause: error);
    }

    final Object? entries = json['collections'];
    if (entries is! List) {
      throw const CatalogUnavailableException();
    }

    final List<HadithCollection> collections = entries
        .whereType<Map<String, Object?>>()
        .map(CollectionDto.fromJson)
        .toList(growable: false);
    _catalogCache = collections;
    return collections;
  }

  @override
  Future<bool> hasContentFor(String collectionId) async {
    final HadithCollection? collection = await _collectionById(collectionId);
    if (collection == null) return false;
    try {
      await _readCollectionFile(collection);
      return true;
    } on AppException {
      return false;
    }
  }

  @override
  Future<List<Hadith>> loadHadith(String collectionId) async {
    final HadithCollection? collection = await _collectionById(collectionId);
    if (collection == null) throw DatasetUnavailableException(collectionId);

    final Map<String, Object?> file = await _readCollectionFile(collection);
    final Object? entries = file['hadith'];
    if (entries is! List) {
      throw ContentFormatException(
        'The data file for "$collectionId" has no "hadith" list.',
      );
    }

    final String fallbackSource = collection.source.name;
    final List<Hadith> hadith = <Hadith>[];
    int ordinal = 0;
    for (final Object? entry in entries) {
      if (entry is! Map<String, Object?>) continue;
      ordinal++;
      hadith.add(
        HadithDto.fromJson(
          entry,
          collectionId: collectionId,
          ordinal: ordinal,
          fallbackSource: fallbackSource,
        ),
      );
    }

    if (hadith.isEmpty) {
      throw DatasetUnavailableException(collectionId);
    }
    return hadith;
  }

  @override
  Future<List<HadithChapter>> loadChapters(String collectionId) async {
    final HadithCollection? collection = await _collectionById(collectionId);
    if (collection == null) return const <HadithChapter>[];
    final Map<String, Object?> file;
    try {
      file = await _readCollectionFile(collection);
    } on AppException {
      return const <HadithChapter>[];
    }
    final Object? entries = file['chapters'];
    if (entries is! List) return const <HadithChapter>[];
    return entries
        .whereType<Map<String, Object?>>()
        .map((Map<String, Object?> json) =>
            HadithDto.chapterFromJson(json, collectionId: collectionId))
        .toList(growable: false);
  }

  Future<HadithCollection?> _collectionById(String collectionId) async {
    final List<HadithCollection> catalog = await loadCatalog();
    for (final HadithCollection collection in catalog) {
      if (collection.id == collectionId) return collection;
    }
    return null;
  }

  Future<Map<String, Object?>> _readCollectionFile(
    HadithCollection collection,
  ) =>
      _readJson(ContentSchema.assetForSlug(collection.slug));

  Future<Map<String, Object?>> _readJson(String asset) async {
    final String raw;
    try {
      raw = await _assets.loadString(asset);
    } on Object catch (error) {
      throw ContentFormatException('Missing asset "$asset".', cause: error);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw ContentFormatException('"$asset" is not valid JSON.', cause: error);
    }
    if (decoded is! Map<String, Object?>) {
      throw ContentFormatException('"$asset" must contain a JSON object.');
    }
    return decoded;
  }

  /// Drops the memoised catalog, so newly added content is picked up without a
  /// restart.
  void clearCache() => _catalogCache = null;
}
