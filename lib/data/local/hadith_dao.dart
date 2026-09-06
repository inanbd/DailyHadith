import 'package:sqflite/sqflite.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/entities/hadith.dart';
import 'app_database.dart';

/// Reads and writes the local copy of hadith text.
class HadithDao {
  HadithDao(this._database);

  final AppDatabase _database;

  /// Replaces a collection's stored text in one transaction, so an interrupted
  /// import can never leave a half-installed book behind.
  Future<void> replaceCollection(
    String collectionId,
    String slug,
    List<Hadith> hadith,
    List<HadithChapter> chapters,
  ) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        AppDatabase.hadithTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
      await txn.delete(
        AppDatabase.chaptersTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );

      final Batch batch = txn.batch();
      for (final Hadith item in hadith) {
        batch.insert(
          AppDatabase.hadithTable,
          _toRow(item),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final HadithChapter chapter in chapters) {
        batch.insert(
          AppDatabase.chaptersTable,
          <String, Object?>{
            'collection_id': chapter.collectionId,
            'chapter_number': chapter.chapterNumber,
            'book_number': chapter.bookNumber,
            'title_english': chapter.titleEnglish,
            'title_arabic': chapter.titleArabic,
            'hadith_count': chapter.hadithCount,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch.insert(
        AppDatabase.collectionsTable,
        <String, Object?>{
          'id': collectionId,
          'slug': slug,
          'installed_count': hadith.length,
          'installed_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  Future<int> countFor(String collectionId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.hadithTable} '
      'WHERE collection_id = ?',
      <Object?>[collectionId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Ids of every collection with text stored locally.
  Future<Set<String>> installedCollectionIds() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT collection_id AS id FROM ${AppDatabase.hadithTable}',
    );
    return rows.map((Map<String, Object?> row) => row['id']! as String).toSet();
  }

  Future<Hadith?> byOrdinal(String collectionId, int ordinal) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.hadithTable,
      where: 'collection_id = ? AND ordinal = ?',
      whereArgs: <Object?>[collectionId, ordinal],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<Hadith?> byId(String hadithId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.hadithTable,
      where: 'id = ?',
      whereArgs: <Object?>[hadithId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<HadithChapter>> chapters(String collectionId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.chaptersTable,
      where: 'collection_id = ?',
      whereArgs: <Object?>[collectionId],
      orderBy: 'chapter_number ASC',
    );
    return rows
        .map(
          (Map<String, Object?> row) => HadithChapter(
            collectionId: row['collection_id']! as String,
            chapterNumber: row['chapter_number']! as int,
            bookNumber: row['book_number'] as int?,
            titleEnglish: (row['title_english'] as String?) ?? '',
            titleArabic: (row['title_arabic'] as String?) ?? '',
            hadithCount: (row['hadith_count'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// The reading position of the first hadith in a chapter, or null when the
  /// chapter has no hadith stored against it.
  ///
  /// Chapter metadata and hadith rows are imported separately, so a chapter can
  /// legitimately exist with nothing pointing at it; the caller treats that as
  /// "not navigable" rather than an error.
  Future<int?> firstOrdinalOfChapter(
    String collectionId,
    int chapterNumber,
  ) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.hadithTable,
      columns: <String>['ordinal'],
      where: 'collection_id = ? AND chapter_number = ?',
      whereArgs: <Object?>[collectionId, chapterNumber],
      orderBy: 'ordinal ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['ordinal'] as int?;
  }

  Future<void> deleteCollection(String collectionId) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        AppDatabase.hadithTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
      await txn.delete(
        AppDatabase.chaptersTable,
        where: 'collection_id = ?',
        whereArgs: <Object?>[collectionId],
      );
      await txn.delete(
        AppDatabase.collectionsTable,
        where: 'id = ?',
        whereArgs: <Object?>[collectionId],
      );
    });
  }

  static Map<String, Object?> _toRow(Hadith hadith) => <String, Object?>{
        'id': hadith.id,
        'collection_id': hadith.collectionId,
        'ordinal': hadith.ordinal,
        'hadith_number': hadith.hadithNumber,
        'book_number': hadith.bookNumber,
        'chapter_number': hadith.chapterNumber,
        'chapter_english': hadith.chapterEnglish,
        'chapter_arabic': hadith.chapterArabic,
        'arabic_text': hadith.arabicText,
        'english_text': hadith.englishText,
        'narrator': hadith.narrator,
        'grade': hadith.grade,
        'reference': hadith.reference,
        'source': hadith.source,
      };

  static Hadith _fromRow(Map<String, Object?> row) => Hadith(
        id: row['id']! as String,
        collectionId: row['collection_id']! as String,
        ordinal: row['ordinal']! as int,
        hadithNumber: row['hadith_number']! as String,
        bookNumber: row['book_number'] as int?,
        chapterNumber: row['chapter_number'] as int?,
        chapterEnglish: row['chapter_english'] as String?,
        chapterArabic: row['chapter_arabic'] as String?,
        arabicText: row['arabic_text'] as String?,
        englishText: row['english_text'] as String?,
        narrator: row['narrator'] as String?,
        grade: row['grade'] as String?,
        reference: row['reference'] as String?,
        source: row['source'] as String?,
      );
}
