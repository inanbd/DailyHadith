import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and migrates the app's SQLite database.
///
/// The database holds two very different kinds of data: a local *copy* of the
/// hadith text (so reading works offline and paging a 2,000-entry book is
/// cheap) and the reader's own progress. Only the latter is irreplaceable —
/// hadith rows can always be re-imported from the content source.
class AppDatabase {
  AppDatabase({this.factoryOverride, this.pathOverride});


  static const String fileName = 'daily_hadith.db';
  static const int schemaVersion = 1;

  static const String collectionsTable = 'collections';
  static const String hadithTable = 'hadith';
  static const String chaptersTable = 'chapters';
  static const String progressTable = 'reading_progress';
  static const String readTable = 'read_hadith';

  /// Injected in tests to run against an in-memory FFI database.
  final DatabaseFactory? factoryOverride;

  /// Injected in tests, or to place the database file somewhere other than the
  /// platform default.
  final String? pathOverride;

  Database? _db;
  Future<Database>? _opening;

  /// The open database, opening it on first use. Concurrent callers share a
  /// single open operation.
  Future<Database> get database async {
    final Database? existing = _db;
    if (existing != null && existing.isOpen) return existing;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<Database> _open() async {
    final DatabaseFactory factory = factoryOverride ?? databaseFactory;
    final String path =
        pathOverride ?? p.join(await factory.getDatabasesPath(), fileName);
    final Database db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await _createSchema(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          // Only v1 exists today. Future migrations append here; hadith tables
          // may be dropped and re-imported, progress tables must be preserved.
        },
      ),
    );
    _db = db;
    return db;
  }

  static Future<void> _createSchema(Database db) async {
    final Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE $collectionsTable (
        id TEXT PRIMARY KEY,
        slug TEXT NOT NULL,
        installed_count INTEGER NOT NULL DEFAULT 0,
        installed_at INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE $hadithTable (
        id TEXT PRIMARY KEY,
        collection_id TEXT NOT NULL,
        ordinal INTEGER NOT NULL,
        hadith_number TEXT NOT NULL,
        book_number INTEGER,
        chapter_number INTEGER,
        chapter_english TEXT,
        chapter_arabic TEXT,
        arabic_text TEXT,
        english_text TEXT,
        narrator TEXT,
        grade TEXT,
        reference TEXT,
        source TEXT
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_hadith_position '
      'ON $hadithTable (collection_id, ordinal)',
    );

    batch.execute('''
      CREATE TABLE $chaptersTable (
        collection_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        book_number INTEGER,
        title_english TEXT NOT NULL DEFAULT '',
        title_arabic TEXT NOT NULL DEFAULT '',
        hadith_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (collection_id, chapter_number)
      )
    ''');

    batch.execute('''
      CREATE TABLE $progressTable (
        collection_id TEXT PRIMARY KEY,
        current_ordinal INTEGER NOT NULL DEFAULT 1,
        started_at INTEGER,
        last_read_at INTEGER,
        completed_at INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE $readTable (
        collection_id TEXT NOT NULL,
        hadith_id TEXT NOT NULL,
        ordinal INTEGER NOT NULL,
        read_at INTEGER NOT NULL,
        PRIMARY KEY (collection_id, hadith_id)
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_read_position ON $readTable (collection_id, ordinal)',
    );

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }
}
