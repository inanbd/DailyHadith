import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// One saved-hadith row, before its text has been resolved.
class FavouriteRecord {
  const FavouriteRecord({
    required this.collectionId,
    required this.hadithId,
    required this.ordinal,
    required this.savedAt,
  });

  final String collectionId;
  final String hadithId;
  final int ordinal;
  final DateTime savedAt;
}

/// Favourite storage.
///
/// Rows are keyed by collection and hadith, so saving the same hadith twice is
/// idempotent and removing one book's text never touches another's.
class FavouritesDao {
  FavouritesDao(this._database);

  final AppDatabase _database;

  Future<List<FavouriteRecord>> all() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.favouritesTable,
      orderBy: 'saved_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<bool> isFavourite(String collectionId, String hadithId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.favouritesTable,
      columns: <String>['hadith_id'],
      where: 'collection_id = ? AND hadith_id = ?',
      whereArgs: <Object?>[collectionId, hadithId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> add(
    String collectionId,
    String hadithId,
    int ordinal, {
    DateTime? at,
  }) async {
    final Database db = await _database.database;
    await db.insert(
      AppDatabase.favouritesTable,
      <String, Object?>{
        'collection_id': collectionId,
        'hadith_id': hadithId,
        'ordinal': ordinal,
        'saved_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
      },
      // Re-saving keeps the row but refreshes when it was saved, which is what
      // puts it back at the top of the list.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String collectionId, String hadithId) async {
    final Database db = await _database.database;
    await db.delete(
      AppDatabase.favouritesTable,
      where: 'collection_id = ? AND hadith_id = ?',
      whereArgs: <Object?>[collectionId, hadithId],
    );
  }

  Future<int> count() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.favouritesTable}',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static FavouriteRecord _fromRow(Map<String, Object?> row) => FavouriteRecord(
        collectionId: row['collection_id']! as String,
        hadithId: row['hadith_id']! as String,
        ordinal: (row['ordinal'] as int?) ?? 1,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['saved_at'] as int?) ?? 0,
        ),
      );
}
