import 'package:sqflite/sqflite.dart';

import '../../domain/entities/reading_progress.dart';
import 'app_database.dart';

/// Reading progress storage.
///
/// Read state is stored as one row per hadith actually read. Nothing is ever
/// inferred in bulk, which is what guarantees that skipping ahead — or missing
/// a week — leaves the skipped hadith unread.
class ProgressDao {
  ProgressDao(this._database);

  final AppDatabase _database;

  Future<ReadingProgress> progressFor(String collectionId, int totalHadith) async {
    final Database db = await _database.database;
    return _read(db, collectionId, totalHadith);
  }

  Future<List<ReadingProgress>> allProgress(Map<String, int> totals) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.progressTable,
      orderBy: 'last_read_at DESC',
    );
    final List<ReadingProgress> result = <ReadingProgress>[];
    for (final Map<String, Object?> row in rows) {
      final String id = row['collection_id']! as String;
      result.add(await _read(db, id, totals[id] ?? 0));
    }
    return result;
  }

  Future<ReadingProgress> markRead(
    String collectionId,
    String hadithId,
    int ordinal,
    int totalHadith, {
    DateTime? at,
  }) async {
    final Database db = await _database.database;
    final int timestamp = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      await txn.insert(
        AppDatabase.readTable,
        <String, Object?>{
          'collection_id': collectionId,
          'hadith_id': hadithId,
          'ordinal': ordinal,
          'read_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _touch(
        txn,
        collectionId,
        currentOrdinal: ordinal,
        lastReadAt: timestamp,
        startedAtIfMissing: timestamp,
      );
      await _refreshCompletion(txn, collectionId, totalHadith, timestamp);
    });
    return _read(db, collectionId, totalHadith);
  }

  Future<ReadingProgress> markUnread(
    String collectionId,
    String hadithId,
    int totalHadith,
  ) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        AppDatabase.readTable,
        where: 'collection_id = ? AND hadith_id = ?',
        whereArgs: <Object?>[collectionId, hadithId],
      );
      // Un-reading anything necessarily un-completes the book.
      await txn.update(
        AppDatabase.progressTable,
        <String, Object?>{'completed_at': null},
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
      await _refreshCompletion(
        txn,
        collectionId,
        totalHadith,
        DateTime.now().millisecondsSinceEpoch,
      );
    });
    return _read(db, collectionId, totalHadith);
  }

  Future<ReadingProgress> setCurrentOrdinal(
    String collectionId,
    int ordinal,
    int totalHadith,
  ) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await _touch(txn, collectionId, currentOrdinal: ordinal);
    });
    return _read(db, collectionId, totalHadith);
  }

  Future<bool> isRead(String collectionId, String hadithId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.readTable,
      columns: <String>['hadith_id'],
      where: 'collection_id = ? AND hadith_id = ?',
      whereArgs: <Object?>[collectionId, hadithId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<int>> readOrdinalsIn(String collectionId, int from, int to) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.readTable,
      columns: <String>['ordinal'],
      where: 'collection_id = ? AND ordinal BETWEEN ? AND ?',
      whereArgs: <Object?>[collectionId, from, to],
    );
    return rows
        .map((Map<String, Object?> row) => row['ordinal']! as int)
        .toSet();
  }

  /// Lowest unread ordinal in `1..totalHadith`, or null when all are read.
  ///
  /// Resolved with two indexed queries rather than by loading the read set, so
  /// it stays cheap on a 2,000-hadith book.
  Future<int?> firstUnreadOrdinal(String collectionId, int totalHadith) async {
    if (totalHadith <= 0) return null;
    final Database db = await _database.database;
    return _firstUnread(db, collectionId, totalHadith);
  }

  Future<ReadingProgress> resetCollection(
    String collectionId,
    int totalHadith,
  ) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        AppDatabase.readTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
      await txn.delete(
        AppDatabase.progressTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
    });
    return _read(db, collectionId, totalHadith);
  }

  static Future<int?> _firstUnread(
    DatabaseExecutor db,
    String collectionId,
    int totalHadith,
  ) async {
    final List<Map<String, Object?>> firstRow = await db.query(
      AppDatabase.readTable,
      columns: <String>['ordinal'],
      where: 'collection_id = ? AND ordinal = 1',
      whereArgs: <Object?>[collectionId],
      limit: 1,
    );
    if (firstRow.isEmpty) return 1;

    // The lowest ordinal that is read while its successor is not: the start of
    // the first gap.
    final List<Map<String, Object?>> gap = await db.rawQuery(
      '''
      SELECT MIN(t.ordinal + 1) AS next FROM ${AppDatabase.readTable} t
      WHERE t.collection_id = ?
        AND NOT EXISTS (
          SELECT 1 FROM ${AppDatabase.readTable} r
          WHERE r.collection_id = t.collection_id AND r.ordinal = t.ordinal + 1
        )
      ''',
      <Object?>[collectionId],
    );
    final Object? next = gap.isEmpty ? null : gap.first['next'];
    if (next is! int) return null;
    if (next > totalHadith) return null;
    return next;
  }

  static Future<void> _touch(
    Transaction txn,
    String collectionId, {
    int? currentOrdinal,
    int? lastReadAt,
    int? startedAtIfMissing,
  }) async {
    final List<Map<String, Object?>> existing = await txn.query(
      AppDatabase.progressTable,
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await txn.insert(AppDatabase.progressTable, <String, Object?>{
        'collection_id': collectionId,
        'current_ordinal': currentOrdinal ?? 1,
        'started_at': startedAtIfMissing,
        'last_read_at': lastReadAt,
        'completed_at': null,
      });
      return;
    }

    final Map<String, Object?> update = <String, Object?>{};
    if (currentOrdinal != null) update['current_ordinal'] = currentOrdinal;
    if (lastReadAt != null) update['last_read_at'] = lastReadAt;
    if (startedAtIfMissing != null && existing.first['started_at'] == null) {
      update['started_at'] = startedAtIfMissing;
    }
    if (update.isEmpty) return;

    await txn.update(
      AppDatabase.progressTable,
      update,
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
    );
  }

  /// Stamps or clears `completed_at` to match the current read count.
  static Future<void> _refreshCompletion(
    Transaction txn,
    String collectionId,
    int totalHadith,
    int timestamp,
  ) async {
    if (totalHadith <= 0) return;
    final int? firstUnread = await _firstUnread(txn, collectionId, totalHadith);
    if (firstUnread == null) {
      await txn.update(
        AppDatabase.progressTable,
        <String, Object?>{'completed_at': timestamp},
        where: 'collection_id = ? AND completed_at IS NULL',
        whereArgs: <Object?>[collectionId],
      );
    } else {
      await txn.update(
        AppDatabase.progressTable,
        <String, Object?>{'completed_at': null},
        where: 'collection_id = ? AND completed_at IS NOT NULL',
        whereArgs: <Object?>[collectionId],
      );
    }
  }

  static Future<ReadingProgress> _read(
    Database db,
    String collectionId,
    int totalHadith,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.progressTable,
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
      limit: 1,
    );

    final List<Map<String, Object?>> countRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.readTable} '
      'WHERE collection_id = ? AND ordinal >= 1 AND ordinal <= ?',
      <Object?>[collectionId, totalHadith],
    );
    final int totalRead = Sqflite.firstIntValue(countRows) ?? 0;

    if (rows.isEmpty) {
      return ReadingProgress(
        collectionId: collectionId,
        currentOrdinal: 1,
        totalRead: totalRead,
        totalHadith: totalHadith,
      );
    }

    final Map<String, Object?> row = rows.first;
    return ReadingProgress(
      collectionId: collectionId,
      currentOrdinal: (row['current_ordinal'] as int?) ?? 1,
      totalRead: totalRead,
      totalHadith: totalHadith,
      startedAt: _time(row['started_at']),
      lastReadAt: _time(row['last_read_at']),
      completedAt: _time(row['completed_at']),
    );
  }

  static DateTime? _time(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}
