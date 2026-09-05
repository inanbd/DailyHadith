import '../entities/favourite_hadith.dart';

/// Saved hadith, spanning every collection.
///
/// Favourites are the reader's own data: nothing here is derived from reading
/// progress, and re-importing a collection never clears them.
abstract interface class FavouritesRepository {
  /// Every favourite, most recently saved first, with its text resolved.
  ///
  /// Entries whose hadith is no longer in local storage are skipped rather
  /// than surfaced as blanks — the row stays, so it reappears if the
  /// collection is reinstalled.
  Future<List<FavouriteHadith>> all();

  Future<bool> isFavourite(String collectionId, String hadithId);

  /// Adds or removes [hadithId], returning whether it is a favourite after
  /// the change.
  Future<bool> toggle(String collectionId, String hadithId, int ordinal);

  Future<int> count();
}
