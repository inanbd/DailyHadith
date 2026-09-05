import 'dart:io';

import 'package:daily_hadith/data/local/app_database.dart';
import 'package:daily_hadith/data/local/favourites_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The parts of the v1 schema this test writes into, copied verbatim from the
/// shipped v1 so the upgrade is exercised against what readers actually have.
const String _v1Progress = '''
  CREATE TABLE reading_progress (
    collection_id TEXT PRIMARY KEY,
    current_ordinal INTEGER NOT NULL DEFAULT 1,
    started_at INTEGER,
    last_read_at INTEGER,
    completed_at INTEGER
  )
''';

const String _v1Read = '''
  CREATE TABLE read_hadith (
    collection_id TEXT NOT NULL,
    hadith_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    read_at INTEGER NOT NULL,
    PRIMARY KEY (collection_id, hadith_id)
  )
''';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory directory;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('daily_hadith_migration');
    path = p.join(directory.path, 'daily_hadith.db');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  /// Writes a v1 database carrying some reading progress.
  Future<void> seedV1() async {
    final Database db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(_v1Progress);
          await db.execute(_v1Read);
        },
      ),
    );
    await db.insert('reading_progress', <String, Object?>{
      'collection_id': 'riyad_as_salihin',
      'current_ordinal': 42,
      'started_at': 1700000000000,
      'last_read_at': 1700000900000,
    });
    await db.insert('read_hadith', <String, Object?>{
      'collection_id': 'riyad_as_salihin',
      'hadith_id': 'riyad_as_salihin:1',
      'ordinal': 1,
      'read_at': 1700000000000,
    });
    await db.close();
  }

  test('upgrading from v1 keeps reading progress', () async {
    await seedV1();

    final AppDatabase upgraded = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: path,
    );
    addTearDown(upgraded.close);
    final Database db = await upgraded.database;

    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final List<Map<String, Object?>> progress =
        await db.query('reading_progress');
    expect(progress, hasLength(1));
    expect(progress.first['current_ordinal'], 42);

    final List<Map<String, Object?>> read = await db.query('read_hadith');
    expect(read, hasLength(1));
  });

  test('upgrading from v1 adds a usable favourites table', () async {
    await seedV1();

    final AppDatabase upgraded = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: path,
    );
    addTearDown(upgraded.close);
    final FavouritesDao dao = FavouritesDao(upgraded);

    expect(await dao.count(), 0);

    await dao.add('riyad_as_salihin', 'riyad_as_salihin:1', 1);

    expect(await dao.isFavourite('riyad_as_salihin', 'riyad_as_salihin:1'),
        isTrue);
  });

  test('a fresh install and an upgraded one agree on the schema', () async {
    await seedV1();
    final AppDatabase upgraded = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: path,
    );
    addTearDown(upgraded.close);
    final Database upgradedDb = await upgraded.database;

    final AppDatabase fresh = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: p.join(directory.path, 'fresh.db'),
    );
    addTearDown(fresh.close);
    final Database freshDb = await fresh.database;

    Future<List<String>> tables(Database db) async {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      return rows.map((Map<String, Object?> r) => r['name']! as String).toList();
    }

    expect(await tables(upgradedDb), contains(AppDatabase.favouritesTable));
    expect(await tables(freshDb), contains(AppDatabase.favouritesTable));
  });
}
