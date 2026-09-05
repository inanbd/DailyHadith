import 'package:meta/meta.dart';

/// A chapter within a collection. Chapter browsing is not part of the MVP UI,
/// but the content pipeline preserves chapter metadata so it can be added
/// without touching the data layer.
@immutable
class HadithChapter {
  const HadithChapter({
    required this.collectionId,
    required this.chapterNumber,
    required this.titleEnglish,
    required this.titleArabic,
    required this.hadithCount,
    this.bookNumber,
  });

  final String collectionId;
  final int chapterNumber;
  final String titleEnglish;
  final String titleArabic;
  final int hadithCount;
  final int? bookNumber;
}
