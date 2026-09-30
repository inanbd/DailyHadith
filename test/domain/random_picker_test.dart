import 'dart:math';

import 'package:daily_hadith/domain/services/random_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draws only unread hadith while any remain', () {
    const RandomPoolBook book = RandomPoolBook(
      collectionId: 'a',
      totalHadith: 5,
      read: <int>{1, 2, 4, 5},
    );
    final Random random = Random(1);
    for (int i = 0; i < 20; i++) {
      expect(
        RandomPicker.choose(<RandomPoolBook>[book], random),
        const RandomChoice('a', 3),
      );
    }
  });

  test('avoids hadith already picked for another period', () {
    const RandomPoolBook book = RandomPoolBook(
      collectionId: 'a',
      totalHadith: 3,
      reserved: <int>{1, 3},
    );
    expect(
      RandomPicker.choose(<RandomPoolBook>[book], Random(2)),
      const RandomChoice('a', 2),
    );
  });

  test('starts over once everything in the pool is read', () {
    const RandomPoolBook book = RandomPoolBook(
      collectionId: 'a',
      totalHadith: 3,
      read: <int>{1, 2, 3},
      reserved: <int>{2},
    );
    final Set<RandomChoice> seen = <RandomChoice>{
      for (int seed = 0; seed < 40; seed++)
        RandomPicker.choose(<RandomPoolBook>[book], Random(seed))!,
    };
    // Read hadith come back, but the one reserved elsewhere still does not.
    expect(seen, <RandomChoice>{
      const RandomChoice('a', 1),
      const RandomChoice('a', 3),
    });
  });

  test('is uniform over hadith rather than over books', () {
    const List<RandomPoolBook> pool = <RandomPoolBook>[
      RandomPoolBook(collectionId: 'small', totalHadith: 10),
      RandomPoolBook(collectionId: 'large', totalHadith: 990),
    ];
    final Random random = Random(3);
    int small = 0;
    for (int i = 0; i < 5000; i++) {
      if (RandomPicker.choose(pool, random)!.collectionId == 'small') small++;
    }
    // About 1% of draws; nowhere near the 50% a per-book draw would give.
    expect(small, inInclusiveRange(20, 100));
  });

  test('an empty pool yields nothing', () {
    expect(RandomPicker.choose(const <RandomPoolBook>[], Random(4)), isNull);
    expect(
      RandomPicker.choose(
        const <RandomPoolBook>[RandomPoolBook(collectionId: 'a', totalHadith: 0)],
        Random(4),
      ),
      isNull,
    );
  });
}
