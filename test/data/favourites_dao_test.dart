import 'package:daily_hadith/data/local/app_database.dart';
import 'package:daily_hadith/data/local/favourites_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late FavouritesDao dao;

  setUp(() {
    database = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    dao = FavouritesDao(database);
  });

  tearDown(() => database.close());

  test('a saved hadith reads back as a favourite', () async {
    expect(await dao.isFavourite('book', 'book:1'), isFalse);

    await dao.add('book', 'book:1', 1);

    expect(await dao.isFavourite('book', 'book:1'), isTrue);
    expect(await dao.count(), 1);
  });

  test('removing clears it again', () async {
    await dao.add('book', 'book:1', 1);
    await dao.remove('book', 'book:1');

    expect(await dao.isFavourite('book', 'book:1'), isFalse);
    expect(await dao.count(), 0);
  });

  test('saving the same hadith twice keeps one row', () async {
    await dao.add('book', 'book:1', 1);
    await dao.add('book', 'book:1', 1);

    expect(await dao.count(), 1);
  });

  test('the same ordinal in two books is two favourites', () async {
    await dao.add('one', 'one:1', 1);
    await dao.add('two', 'two:1', 1);

    expect(await dao.count(), 2);
    expect(await dao.isFavourite('one', 'one:1'), isTrue);
    expect(await dao.isFavourite('two', 'two:1'), isTrue);
  });

  test('favourites come back newest first, across books', () async {
    final DateTime base = DateTime(2026, 3, 1, 12);
    await dao.add('one', 'one:5', 5, at: base);
    await dao.add('two', 'two:9', 9, at: base.add(const Duration(hours: 2)));
    await dao.add('one', 'one:2', 2, at: base.add(const Duration(hours: 1)));

    final List<FavouriteRecord> all = await dao.all();

    expect(
      all.map((FavouriteRecord r) => r.hadithId).toList(),
      <String>['two:9', 'one:2', 'one:5'],
    );
    expect(all.first.collectionId, 'two');
    expect(all.first.ordinal, 9);
  });

  test('re-saving moves a favourite back to the top', () async {
    final DateTime base = DateTime(2026, 3, 1, 12);
    await dao.add('one', 'one:1', 1, at: base);
    await dao.add('one', 'one:2', 2, at: base.add(const Duration(hours: 1)));

    await dao.add('one', 'one:1', 1, at: base.add(const Duration(hours: 5)));

    final List<FavouriteRecord> all = await dao.all();
    expect(all.map((FavouriteRecord r) => r.hadithId).toList(),
        <String>['one:1', 'one:2']);
  });
}
