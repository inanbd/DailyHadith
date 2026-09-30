import 'dart:math';

import '../domain/entities/hadith_collection.dart';
import '../domain/entities/random_pick.dart';
import '../domain/repositories/hadith_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/random_pick_repository.dart';
import '../domain/services/random_picker.dart';

/// Chooses, stores and recalls the hadith random mode shows for each reading
/// period.
///
/// A pick is made once per period and then kept, so reopening the app shows
/// the same hadith until the next period, and a reminder that previewed a
/// hadith for a period opens on that same hadith.
class RandomSelection {
  RandomSelection({
    required HadithRepository hadithRepository,
    required ProgressRepository progressRepository,
    required this._picks,
    required this._random,
  })  : _hadith = hadithRepository,
        _progress = progressRepository;

  final HadithRepository _hadith;
  final ProgressRepository _progress;
  final RandomPickRepository _picks;
  final Random _random;

  /// How long picks for past periods are kept. Long enough to cover a reminder
  /// tapped a few days late, short enough that the table stays tiny.
  static const Duration _retention = Duration(days: 7);

  /// The collections in [pool] that can actually be read, in pool order.
  Future<List<HadithCollection>> readablePool(List<String> pool) async {
    if (pool.isEmpty) return const <HadithCollection>[];
    final Map<String, HadithCollection> byId = <String, HadithCollection>{
      for (final HadithCollection collection in await _hadith.collections())
        collection.id: collection,
    };
    return <HadithCollection>[
      for (final String id in pool)
        if (byId[id] case final HadithCollection collection
            when collection.isReadable)
          collection,
    ];
  }

  /// The pick for the period starting at [periodStart], making one if there is
  /// none yet, or if the stored one is from a book no longer in [pool].
  ///
  /// [replace] draws a different hadith for the period even when one exists —
  /// the reader asking to see another.
  Future<RandomPick?> pickFor(
    DateTime periodStart,
    List<HadithCollection> pool, {
    bool replace = false,
  }) async {
    final RandomPick? existing = await _picks.pickFor(periodStart);
    if (existing != null && !replace && _inPool(existing, pool)) {
      return existing;
    }

    final List<RandomPick> reserved = (await _picks.picksFrom(periodStart))
        .where((RandomPick pick) => pick.periodStart != periodStart)
        .toList();
    // Replacing must actually change the hadith, so the current one is held
    // back along with the upcoming ones.
    if (existing != null && replace) reserved.add(existing);

    RandomChoice? choice =
        RandomPicker.choose(await _poolBooks(pool, reserved), _random);
    if (choice != null && _isReserved(choice, reserved)) {
      // Every hadith already has a period. Draw from the whole pool again,
      // holding back only the one being replaced.
      choice = RandomPicker.choose(
        await _poolBooks(pool, <RandomPick>[?existing]),
        _random,
      );
    }
    if (choice == null) return null;

    final RandomPick pick = RandomPick(
      periodStart: periodStart,
      collectionId: choice.collectionId,
      ordinal: choice.ordinal,
    );
    await _picks.save(pick);
    await _picks.deleteBefore(periodStart.subtract(_retention));
    return pick;
  }

  /// Picks for each of [periodStarts], making the missing ones — how the
  /// reminder planner learns what each upcoming reminder should carry.
  ///
  /// New picks avoid each other and every pick already made, so a run of
  /// reminders never repeats a hadith while unread ones remain.
  Future<List<RandomPick>> picksFor(
    List<DateTime> periodStarts,
    List<HadithCollection> pool,
  ) async {
    if (periodStarts.isEmpty || pool.isEmpty) return const <RandomPick>[];

    final DateTime earliest = periodStarts.reduce(
      (DateTime a, DateTime b) => a.isBefore(b) ? a : b,
    );
    final Map<DateTime, RandomPick> existing = <DateTime, RandomPick>{
      for (final RandomPick pick in await _picks.picksFrom(earliest))
        if (_inPool(pick, pool)) pick.periodStart: pick,
    };

    final List<RandomPoolBook> books =
        await _poolBooks(pool, existing.values.toList());
    final Map<String, Set<int>> reserved = <String, Set<int>>{
      for (final RandomPoolBook book in books)
        book.collectionId: <int>{...book.reserved},
    };

    List<RandomPoolBook> withReserved() => <RandomPoolBook>[
          for (final RandomPoolBook book in books)
            RandomPoolBook(
              collectionId: book.collectionId,
              totalHadith: book.totalHadith,
              read: book.read,
              reserved: reserved[book.collectionId]!,
            ),
        ];

    final List<RandomPick> result = <RandomPick>[];
    final List<RandomPick> made = <RandomPick>[];
    for (final DateTime start in periodStarts) {
      final RandomPick? known = existing[start];
      if (known != null) {
        result.add(known);
        continue;
      }
      RandomChoice? choice = RandomPicker.choose(withReserved(), _random);
      if (choice != null && reserved[choice.collectionId]!.contains(choice.ordinal)) {
        // Every hadith in the pool has a period: begin another round,
        // avoiding only the one just before, so none comes twice in a row.
        for (final Set<int> ordinals in reserved.values) {
          ordinals.clear();
        }
        final RandomPick? previous = result.isEmpty ? null : result.last;
        if (previous != null) {
          reserved[previous.collectionId]?.add(previous.ordinal);
        }
        choice = RandomPicker.choose(withReserved(), _random);
      }
      if (choice == null) break;
      reserved[choice.collectionId]!.add(choice.ordinal);
      final RandomPick pick = RandomPick(
        periodStart: start,
        collectionId: choice.collectionId,
        ordinal: choice.ordinal,
      );
      made.add(pick);
      result.add(pick);
    }
    await _picks.saveAll(made);
    return result;
  }

  /// Makes [pick] the hadith for its period — used when the reader opens a
  /// hadith from a reminder, so it stays on screen for the rest of the period.
  Future<void> adopt(RandomPick pick) => _picks.save(pick);

  /// Forgets every pick from [from] on, so the next ones are drawn afresh.
  /// Called when the books random mode draws from change.
  Future<void> forgetFrom(DateTime from) => _picks.deleteFrom(from);

  static bool _isReserved(RandomChoice choice, List<RandomPick> reserved) =>
      reserved.any(
        (RandomPick pick) =>
            pick.collectionId == choice.collectionId &&
            pick.ordinal == choice.ordinal,
      );

  static bool _inPool(RandomPick pick, List<HadithCollection> pool) =>
      pool.any((HadithCollection c) => c.id == pick.collectionId);

  Future<List<RandomPoolBook>> _poolBooks(
    List<HadithCollection> pool,
    List<RandomPick> reserved,
  ) async {
    final List<RandomPoolBook> books = <RandomPoolBook>[];
    for (final HadithCollection collection in pool) {
      final int total = collection.totalHadith;
      books.add(
        RandomPoolBook(
          collectionId: collection.id,
          totalHadith: total,
          read: await _progress.readOrdinalsIn(collection.id, 1, total),
          reserved: <int>{
            for (final RandomPick pick in reserved)
              if (pick.collectionId == collection.id) pick.ordinal,
          },
        ),
      );
    }
    return books;
  }
}
