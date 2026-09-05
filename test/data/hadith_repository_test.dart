import 'package:daily_hadith/core/errors/app_exception.dart';
import 'package:daily_hadith/data/local/app_database.dart';
import 'package:daily_hadith/data/local/hadith_dao.dart';
import 'package:daily_hadith/data/repositories/hadith_repository_impl.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase database;
  late HadithRepositoryImpl repository;
  late FakeContentSource content;

  setUp(() {
    database = AppDatabase(
      factoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    content = FakeContentSource.single(id: 'book', count: 5);
    repository = HadithRepositoryImpl(
      contentSource: content,
      dao: HadithDao(database),
    );
  });

  tearDown(() => database.close());

  test('collections start uninstalled but available', () async {
    final List<HadithCollection> collections = await repository.collections();
    expect(collections, hasLength(1));
    expect(collections.single.isInstalled, isFalse);
    expect(collections.single.isAvailable, isTrue);
    expect(collections.single.isReadable, isTrue);
  });

  test('installing copies the text into local storage', () async {
    final HadithCollection installed =
        await repository.installCollection('book');

    expect(installed.isInstalled, isTrue);
    expect(installed.totalHadith, 5);
    expect(await repository.installedCount('book'), 5);

    final Hadith? first = await repository.hadithAt('book', 1);
    expect(first?.englishText, 'English text number 1.');
    expect(first?.arabicText, 'نص عربي رقم 1');
  });

  test('installing twice does not re-read the source', () async {
    await repository.installCollection('book');
    expect(content.loadHadithCalls, 1);

    await repository.installCollection('book');
    expect(content.loadHadithCalls, 1, reason: 'already installed');

    await repository.installCollection('book', force: true);
    expect(content.loadHadithCalls, 2, reason: 'forced re-import');
    expect(await repository.installedCount('book'), 5);
  });

  test('reads are served from storage, so the source is not needed again',
      () async {
    await repository.installCollection('book');
    final int callsAfterInstall = content.loadHadithCalls;

    for (int ordinal = 1; ordinal <= 5; ordinal++) {
      expect((await repository.hadithAt('book', ordinal))?.ordinal, ordinal);
    }
    expect(content.loadHadithCalls, callsAfterInstall);
  });

  test('out-of-range positions return null rather than throwing', () async {
    await repository.installCollection('book');
    expect(await repository.hadithAt('book', 0), isNull);
    expect(await repository.hadithAt('book', -1), isNull);
    expect(await repository.hadithAt('book', 6), isNull);
  });

  test('a collection missing from the catalog cannot be installed', () async {
    expect(
      () => repository.installCollection('nope'),
      throwsA(isA<DatasetUnavailableException>()),
    );
  });

  test('the stored count wins over the catalog total', () async {
    // The catalog claims 5; storage is what progress is actually measured
    // against.
    await repository.installCollection('book');
    final HadithCollection? collection = await repository.collection('book');
    expect(collection?.totalHadith, 5);
    expect(collection?.isInstalled, isTrue);
  });

  test('a catalog entry with no content is listed but not readable', () async {
    final FakeContentSource catalogOnly = FakeContentSource(
      collections: content.collections,
      hadithByCollection: const <String, List<Hadith>>{},
    );
    final HadithRepositoryImpl repo = HadithRepositoryImpl(
      contentSource: catalogOnly,
      dao: HadithDao(database),
    );

    final List<HadithCollection> collections = await repo.collections();
    expect(collections.single.isAvailable, isFalse);
    expect(collections.single.isReadable, isFalse);
  });
}
