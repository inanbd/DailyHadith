import 'package:sqflite/sqflite.dart';

import '../../domain/entities/random_pick.dart';
import '../../domain/repositories/random_pick_repository.dart';
import 'app_database.dart';

/// SQLite storage for random-mode picks, keyed by the start of the reading
/// period they belong to.
class RandomPickDao implements RandomPickRepository {
  RandomPickDao(this._database);

  final AppDatabase _database;

  @override
  Future<RandomPick?> pickFor(DateTime periodStart) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.randomPicksTable,
      where: 'period_start = ?',
      whereArgs: <Object?>[periodStart.millisecondsSinceEpoch],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<RandomPick>> picksFrom(DateTime from) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.randomPicksTable,
      where: 'period_start >= ?',
      whereArgs: <Object?>[from.millisecondsSinceEpoch],
      orderBy: 'period_start ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(RandomPick pick) => saveAll(<RandomPick>[pick]);

  @override
  Future<void> saveAll(List<RandomPick> picks) async {
    if (picks.isEmpty) return;
    final Database db = await _database.database;
    final Batch batch = db.batch();
    for (final RandomPick pick in picks) {
      batch.insert(
        AppDatabase.randomPicksTable,
        <String, Object?>{
          'period_start': pick.periodStart.millisecondsSinceEpoch,
          'collection_id': pick.collectionId,
          'ordinal': pick.ordinal,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteFrom(DateTime from) async {
    final Database db = await _database.database;
    await db.delete(
      AppDatabase.randomPicksTable,
      where: 'period_start >= ?',
      whereArgs: <Object?>[from.millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> deleteBefore(DateTime before) async {
    final Database db = await _database.database;
    await db.delete(
      AppDatabase.randomPicksTable,
      where: 'period_start < ?',
      whereArgs: <Object?>[before.millisecondsSinceEpoch],
    );
  }

  static RandomPick _fromRow(Map<String, Object?> row) => RandomPick(
        periodStart:
            DateTime.fromMillisecondsSinceEpoch(row['period_start']! as int),
        collectionId: row['collection_id']! as String,
        ordinal: row['ordinal']! as int,
      );
}
