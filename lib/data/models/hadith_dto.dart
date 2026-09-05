import '../../domain/entities/chapter.dart';
import '../../domain/entities/hadith.dart';

/// Parses hadith entries from a collection file.
///
/// Text is copied through untouched — no trimming of content, no
/// normalisation, no substitution. Only whitespace-only values become null.
abstract final class HadithDto {
  static Hadith fromJson(
    Map<String, Object?> json, {
    required String collectionId,
    required int ordinal,
    String? fallbackSource,
  }) {
    final String hadithNumber =
        _string(json['hadithNumber']) ?? ordinal.toString();
    return Hadith(
      id: '$collectionId:$hadithNumber#$ordinal',
      collectionId: collectionId,
      ordinal: ordinal,
      hadithNumber: hadithNumber,
      bookNumber: _int(json['bookNumber']),
      chapterNumber: _int(json['chapterNumber']),
      chapterEnglish: _string(json['chapterEnglish']),
      chapterArabic: _string(json['chapterArabic']),
      arabicText: _string(json['arabic']),
      englishText: _string(json['english']),
      narrator: _string(json['narrator']),
      grade: _string(json['grade']),
      reference: _string(json['reference']),
      source: _string(json['source']) ?? fallbackSource,
    );
  }

  static HadithChapter chapterFromJson(
    Map<String, Object?> json, {
    required String collectionId,
  }) {
    return HadithChapter(
      collectionId: collectionId,
      chapterNumber: _int(json['chapterNumber']) ?? _int(json['number']) ?? 0,
      bookNumber: _int(json['bookNumber']),
      titleEnglish: _string(json['titleEnglish']) ?? '',
      titleArabic: _string(json['titleArabic']) ?? '',
      hadithCount: _int(json['hadithCount']) ?? 0,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    return value.trim().isEmpty ? null : value;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
