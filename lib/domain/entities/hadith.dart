import 'package:meta/meta.dart';

/// A single hadith as stored and displayed.
///
/// Text fields are reproduced verbatim from the configured content source and
/// are never generated, paraphrased, or edited by the app.
@immutable
class Hadith {
  const Hadith({
    required this.id,
    required this.collectionId,
    required this.ordinal,
    required this.hadithNumber,
    this.bookNumber,
    this.chapterNumber,
    this.chapterEnglish,
    this.chapterArabic,
    this.arabicText,
    this.englishText,
    this.narrator,
    this.grade,
    this.reference,
    this.source,
  });

  /// Globally unique id, e.g. `riyad_as_salihin:24`.
  final String id;

  final String collectionId;

  /// 1-based reading position within the collection. This is the sequence the
  /// app reads in; [hadithNumber] is what the source calls the hadith and can
  /// be non-numeric (`"1a"`) or repeated across volumes.
  final int ordinal;

  /// Display number as published by the source.
  final String hadithNumber;

  final int? bookNumber;
  final int? chapterNumber;
  final String? chapterEnglish;
  final String? chapterArabic;

  /// Original Arabic text. Null when the source has no Arabic for this entry.
  final String? arabicText;

  /// Translation. Null when the source has no translation for this entry.
  final String? englishText;

  /// Chain/narrator line, e.g. "Narrated Abu Hurairah (RA)".
  final String? narrator;

  /// Grading as published by the source (e.g. "Sahih"). Never inferred.
  final String? grade;

  /// Citation string, e.g. "Riyad as-Salihin 24".
  final String? reference;

  /// Per-hadith attribution, when it differs from the collection's.
  final String? source;

  bool get hasArabic => (arabicText ?? '').trim().isNotEmpty;
  bool get hasEnglish => (englishText ?? '').trim().isNotEmpty;
  bool get hasAnyText => hasArabic || hasEnglish;

  @override
  bool operator ==(Object other) => other is Hadith && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
