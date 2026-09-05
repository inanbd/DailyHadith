import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/entities/reading_progress.dart';
import 'package:daily_hadith/domain/services/reading_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const NotificationPreferences daily = NotificationPreferences(
    enabled: true,
    frequency: NotificationFrequency.daily,
    selectedWeekdays: <int>{1, 2, 3, 4, 5, 6, 7},
    time: TimeOfDayValue(8, 0),
  );

  ReadingProgress progress({
    required int currentOrdinal,
    required int totalRead,
    int totalHadith = 100,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      collectionId: 'c',
      currentOrdinal: currentOrdinal,
      totalRead: totalRead,
      totalHadith: totalHadith,
      startedAt: lastReadAt,
      lastReadAt: lastReadAt,
    );
  }

  int resolve({
    required ReadingProgress state,
    required int? firstUnread,
    required DateTime now,
  }) {
    return ReadingScheduler.resolveTodaysOrdinal(
      progress: state,
      firstUnreadOrdinal: firstUnread,
      notificationPreferences: daily,
      now: now,
    );
  }

  test('a brand new reader starts at the first hadith', () {
    expect(
      resolve(
        state: progress(currentOrdinal: 1, totalRead: 0),
        firstUnread: 1,
        now: DateTime(2026, 1, 7, 9, 0),
      ),
      1,
    );
  });

  test('holds position after reading within the same period', () {
    // Read at 08:30; re-opening at 20:00 the same day shows the same hadith.
    expect(
      resolve(
        state: progress(
          currentOrdinal: 1,
          totalRead: 1,
          lastReadAt: DateTime(2026, 1, 7, 8, 30),
        ),
        firstUnread: 2,
        now: DateTime(2026, 1, 7, 20, 0),
      ),
      1,
    );
  });

  test('moves to the next unread hadith in a new period', () {
    // Read yesterday at 08:30, opening today at 08:05 — the 08:00 boundary has
    // been crossed, so the book moves on.
    expect(
      resolve(
        state: progress(
          currentOrdinal: 1,
          totalRead: 1,
          lastReadAt: DateTime(2026, 1, 6, 8, 30),
        ),
        firstUnread: 2,
        now: DateTime(2026, 1, 7, 8, 5),
      ),
      2,
    );
  });

  test('does not move on before the reminder time', () {
    // Read yesterday at 20:00; at 06:00 today the period has not turned over.
    expect(
      resolve(
        state: progress(
          currentOrdinal: 1,
          totalRead: 1,
          lastReadAt: DateTime(2026, 1, 6, 20, 0),
        ),
        firstUnread: 2,
        now: DateTime(2026, 1, 7, 6, 0),
      ),
      1,
    );
  });

  test('missed days resume at the first unread hadith, not the calendar', () {
    // Two hadith read a fortnight ago; nothing was auto-marked in between.
    expect(
      resolve(
        state: progress(
          currentOrdinal: 2,
          totalRead: 2,
          lastReadAt: DateTime(2026, 1, 1, 8, 30),
        ),
        firstUnread: 3,
        now: DateTime(2026, 1, 15, 9, 0),
      ),
      3,
    );
  });

  test('skipping ahead leaves the skipped hadith to be read next', () {
    // The reader jumped to 50 and read it; 2 is still the first unread.
    expect(
      resolve(
        state: progress(
          currentOrdinal: 50,
          totalRead: 2,
          lastReadAt: DateTime(2026, 1, 6, 9, 0),
        ),
        firstUnread: 2,
        now: DateTime(2026, 1, 7, 9, 0),
      ),
      2,
    );
  });

  test('a finished book stays on its last hadith', () {
    expect(
      resolve(
        state: progress(
          currentOrdinal: 100,
          totalRead: 100,
          lastReadAt: DateTime(2026, 1, 6, 9, 0),
        ),
        firstUnread: null,
        now: DateTime(2026, 1, 9, 9, 0),
      ),
      100,
    );
  });

  test('positions are clamped to the collection', () {
    expect(
      resolve(
        state: progress(currentOrdinal: 500, totalRead: 0, totalHadith: 10),
        firstUnread: 1,
        now: DateTime(2026, 1, 7, 9, 0),
      ),
      1,
    );
    expect(
      resolve(
        state: progress(
          currentOrdinal: 500,
          totalRead: 10,
          totalHadith: 10,
          lastReadAt: DateTime(2026, 1, 6),
        ),
        firstUnread: null,
        now: DateTime(2026, 1, 7, 9, 0),
      ),
      10,
    );
  });

  test('an empty collection resolves to position 1 instead of throwing', () {
    expect(
      resolve(
        state: progress(currentOrdinal: 1, totalRead: 0, totalHadith: 0),
        firstUnread: null,
        now: DateTime(2026, 1, 7),
      ),
      1,
    );
  });
}
