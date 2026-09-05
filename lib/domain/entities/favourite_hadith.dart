import 'package:meta/meta.dart';

import 'hadith.dart';

/// A hadith the reader has saved, with the moment they saved it.
///
/// Favourites are kept across every book, so this carries the hadith itself
/// rather than a position within one collection.
@immutable
class FavouriteHadith {
  const FavouriteHadith({required this.hadith, required this.savedAt});

  final Hadith hadith;
  final DateTime savedAt;

  String get collectionId => hadith.collectionId;

  @override
  bool operator ==(Object other) =>
      other is FavouriteHadith &&
      other.hadith.id == hadith.id &&
      other.savedAt == savedAt;

  @override
  int get hashCode => Object.hash(hadith.id, savedAt);
}
