import '../../core/errors/app_exception.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/hadith_collection.dart';

/// Parses catalog entries into [HadithCollection]s.
abstract final class CollectionDto {
  static HadithCollection fromJson(Map<String, Object?> json) {
    final String? id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const ContentFormatException(
        'A catalog entry is missing its "id".',
      );
    }
    final String slug = (json['slug'] as String?) ?? id;
    return HadithCollection(
      id: id,
      slug: slug,
      titleEnglish: (json['titleEnglish'] as String?) ?? id,
      titleArabic: (json['titleArabic'] as String?) ?? '',
      compiler: (json['compiler'] as String?) ?? '',
      compilerArabic: json['compilerArabic'] as String?,
      description: (json['description'] as String?) ?? '',
      totalHadith: _asInt(json['totalHadith']) ?? 0,
      verification:
          ContentVerification.fromStorage(json['verification'] as String?),
      source: sourceFromJson(json['source']),
    );
  }

  static ContentSource sourceFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return const ContentSource(name: 'Unattributed');
    }
    final String? retrieved = raw['retrievedAt'] as String?;
    return ContentSource(
      name: (raw['name'] as String?) ?? 'Unattributed',
      url: raw['url'] as String?,
      translator: raw['translator'] as String?,
      licence: raw['licence'] as String?,
      retrievedAt: retrieved == null ? null : DateTime.tryParse(retrieved),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
