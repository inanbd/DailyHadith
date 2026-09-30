import 'dart:math';

import 'package:meta/meta.dart';

/// One book random mode may draw from, with what it should avoid.
@immutable
class RandomPoolBook {
  const RandomPoolBook({
    required this.collectionId,
    required this.totalHadith,
    this.read = const <int>{},
    this.reserved = const <int>{},
  });

  final String collectionId;
  final int totalHadith;

  /// Ordinals already read. Avoided until everything in the pool is read.
  final Set<int> read;

  /// Ordinals already picked for another period — upcoming reminders, or the
  /// pick being replaced. Avoided while anything else is left.
  final Set<int> reserved;
}

/// A hadith chosen at random: a book and a reading position in it.
@immutable
class RandomChoice {
  const RandomChoice(this.collectionId, this.ordinal);

  final String collectionId;
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      other is RandomChoice &&
      other.collectionId == collectionId &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(collectionId, ordinal);

  @override
  String toString() => 'RandomChoice($collectionId:$ordinal)';
}

/// Chooses a hadith uniformly at random across several books.
///
/// Uniform over hadith, not over books: a 40-hadith book is not drawn as often
/// as a 7,000-hadith one, so the forties are not exhausted in a few weeks.
///
/// Hadith the reader has read are skipped until the whole pool is read, and
/// then the pool starts over. Pure Dart, so it is tested directly.
abstract final class RandomPicker {
  static RandomChoice? choose(List<RandomPoolBook> pool, Random random) {
    // Most to least particular: unread and not already picked; then anything
    // not already picked; then anything at all.
    return _chooseAvoiding(pool, random, avoidRead: true, avoidReserved: true) ??
        _chooseAvoiding(pool, random, avoidRead: false, avoidReserved: true) ??
        _chooseAvoiding(pool, random, avoidRead: false, avoidReserved: false);
  }

  static RandomChoice? _chooseAvoiding(
    List<RandomPoolBook> pool,
    Random random, {
    required bool avoidRead,
    required bool avoidReserved,
  }) {
    bool excluded(RandomPoolBook book, int ordinal) =>
        (avoidRead && book.read.contains(ordinal)) ||
        (avoidReserved && book.reserved.contains(ordinal));

    int availableIn(RandomPoolBook book) {
      int count = 0;
      for (int ordinal = 1; ordinal <= book.totalHadith; ordinal++) {
        if (!excluded(book, ordinal)) count++;
      }
      return count;
    }

    final List<int> available = pool.map(availableIn).toList();
    final int total = available.fold(0, (int sum, int count) => sum + count);
    if (total <= 0) return null;

    int target = random.nextInt(total);
    for (int i = 0; i < pool.length; i++) {
      if (target >= available[i]) {
        target -= available[i];
        continue;
      }
      final RandomPoolBook book = pool[i];
      for (int ordinal = 1; ordinal <= book.totalHadith; ordinal++) {
        if (excluded(book, ordinal)) continue;
        if (target == 0) return RandomChoice(book.collectionId, ordinal);
        target--;
      }
    }
    return null;
  }
}
