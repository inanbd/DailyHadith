import 'package:daily_hadith/data/local/app_database.dart';
import 'package:daily_hadith/data/local/progress_dao.dart';
import 'package:daily_hadith/domain/entities/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase database;
  late ProgressDao dao;

  const String collection = 'c';
  const int total = 10;

  String hadithId(int ordinal) => '$collection:$ordinal';

  setUp(() {
    database = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    dao = ProgressDao(database);
  });

  tearDown(() => database.close());

  test('an untouched collection reports nothing read', () async {
    final ReadingProgress progress = await dao.progressFor(collection, total);
    expect(progress.totalRead, 0);
    expect(progress.currentOrdinal, 1);
    expect(progress.hasStarted, isFalse);
    expect(progress.isComplete, isFalse);
    expect(await dao.firstUnreadOrdinal(collection, total), 1);
  });

  test('marking read records progress and stamps the start date', () async {
    final ReadingProgress progress =
        await dao.markRead(collection, hadithId(1), 1, total);
    expect(progress.totalRead, 1);
    expect(progress.currentOrdinal, 1);
    expect(progress.startedAt, isNotNull);
    expect(progress.lastReadAt, isNotNull);
    expect(await dao.isRead(collection, hadithId(1)), isTrue);
    expect(await dao.firstUnreadOrdinal(collection, total), 2);
  });

  test('marking read twice does not double-count', () async {
    await dao.markRead(collection, hadithId(1), 1, total);
    final ReadingProgress progress =
        await dao.markRead(collection, hadithId(1), 1, total);
    expect(progress.totalRead, 1);
  });

  test('skipping ahead leaves the gap unread', () async {
    await dao.markRead(collection, hadithId(1), 1, total);
    await dao.markRead(collection, hadithId(5), 5, total);

    expect(await dao.firstUnreadOrdinal(collection, total), 2);
    final ReadingProgress progress = await dao.progressFor(collection, total);
    expect(progress.totalRead, 2);
    expect(progress.isComplete, isFalse);
    expect(await dao.readOrdinalsIn(collection, 1, 10), <int>{1, 5});
  });

  test('the first unread is found after a long contiguous run', () async {
    for (int i = 1; i <= 7; i++) {
      await dao.markRead(collection, hadithId(i), i, total);
    }
    expect(await dao.firstUnreadOrdinal(collection, total), 8);
  });

  test('reading everything completes the collection', () async {
    for (int i = 1; i <= total; i++) {
      await dao.markRead(collection, hadithId(i), i, total);
    }
    final ReadingProgress progress = await dao.progressFor(collection, total);
    expect(progress.totalRead, total);
    expect(progress.isComplete, isTrue);
    expect(progress.completedAt, isNotNull);
    expect(progress.percentage, 100);
    expect(await dao.firstUnreadOrdinal(collection, total), isNull);
  });

  test('un-reading one hadith re-opens a completed collection', () async {
    for (int i = 1; i <= total; i++) {
      await dao.markRead(collection, hadithId(i), i, total);
    }
    final ReadingProgress progress =
        await dao.markUnread(collection, hadithId(4), total);

    expect(progress.totalRead, total - 1);
    expect(progress.isComplete, isFalse);
    expect(progress.completedAt, isNull);
    expect(await dao.firstUnreadOrdinal(collection, total), 4);
  });

  test('moving position does not mark anything read', () async {
    final ReadingProgress progress =
        await dao.setCurrentOrdinal(collection, 6, total);
    expect(progress.currentOrdinal, 6);
    expect(progress.totalRead, 0);
    expect(progress.lastReadAt, isNull);
    expect(await dao.firstUnreadOrdinal(collection, total), 1);
  });

  test('each collection keeps its own progress', () async {
    await dao.markRead(collection, hadithId(1), 1, total);
    await dao.markRead('other', 'other:1', 1, 20);
    await dao.markRead('other', 'other:2', 2, 20);

    expect((await dao.progressFor(collection, total)).totalRead, 1);
    expect((await dao.progressFor('other', 20)).totalRead, 2);

    final List<ReadingProgress> all = await dao.allProgress(
      <String, int>{collection: total, 'other': 20},
    );
    expect(all.length, 2);
  });

  test('switching away and back preserves the earlier position', () async {
    await dao.markRead(collection, hadithId(3), 3, total);
    await dao.setCurrentOrdinal(collection, 4, total);

    // Time spent in another book changes nothing here.
    await dao.markRead('other', 'other:1', 1, 20);

    final ReadingProgress progress = await dao.progressFor(collection, total);
    expect(progress.currentOrdinal, 4);
    expect(progress.totalRead, 1);
  });

  test('resetting clears read state so a book can be read again', () async {
    for (int i = 1; i <= total; i++) {
      await dao.markRead(collection, hadithId(i), i, total);
    }
    final ReadingProgress progress =
        await dao.resetCollection(collection, total);

    expect(progress.totalRead, 0);
    expect(progress.currentOrdinal, 1);
    expect(progress.startedAt, isNull);
    expect(progress.completedAt, isNull);
    expect(await dao.firstUnreadOrdinal(collection, total), 1);
  });

  test('rows beyond the collection size are not counted', () async {
    // A dataset that shrank on re-import must not report >100% read.
    await dao.markRead(collection, hadithId(1), 1, total);
    await dao.markRead(collection, hadithId(99), 99, total);

    final ReadingProgress progress = await dao.progressFor(collection, total);
    expect(progress.totalRead, 1);
    expect(progress.fraction, lessThanOrEqualTo(1.0));
  });
}
