import '../../domain/entities/favourite_hadith.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../local/favourites_dao.dart';
import '../local/hadith_dao.dart';

class FavouritesRepositoryImpl implements FavouritesRepository {
  FavouritesRepositoryImpl({
    required this.favouritesDao,
    required this.hadithDao,
  });

  /// Saved-hadith rows.
  final FavouritesDao favouritesDao;

  /// Local storage the saved text is read back from.
  final HadithDao hadithDao;

  @override
  Future<List<FavouriteHadith>> all() async {
    final List<FavouriteRecord> records = await favouritesDao.all();
    final List<FavouriteHadith> result = <FavouriteHadith>[];
    for (final FavouriteRecord record in records) {
      final Hadith? hadith = await hadithDao.byId(record.hadithId);
      // A favourite whose collection has been uninstalled has no text to show.
      // The row is left alone, so it returns if the book is reinstalled.
      if (hadith == null) continue;
      result.add(FavouriteHadith(hadith: hadith, savedAt: record.savedAt));
    }
    return result;
  }

  @override
  Future<bool> isFavourite(String collectionId, String hadithId) =>
      favouritesDao.isFavourite(collectionId, hadithId);

  @override
  Future<bool> toggle(
    String collectionId,
    String hadithId,
    int ordinal,
  ) async {
    final bool wasFavourite =
        await favouritesDao.isFavourite(collectionId, hadithId);
    if (wasFavourite) {
      await favouritesDao.remove(collectionId, hadithId);
      return false;
    }
    await favouritesDao.add(collectionId, hadithId, ordinal);
    return true;
  }

  @override
  Future<int> count() => favouritesDao.count();
}
