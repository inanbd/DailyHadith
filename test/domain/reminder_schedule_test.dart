import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/services/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NotificationPreferences prefs({
    NotificationFrequency frequency = NotificationFrequency.daily,
    Set<int> weekdays = const <int>{1, 2, 3, 4, 5, 6, 7},
    TimeOfDayValue time = const TimeOfDayValue(8, 0),
    List<TimeOfDayValue>? times,
    DateTime? anchor,
  }) {
    return NotificationPreferences(
      enabled: true,
      frequency: frequency,
      selectedWeekdays: weekdays,
      times: times ?? <TimeOfDayValue>[time],
      anchorDate: anchor,
    );
  }

  group('daily', () {
    test('fires today when the time has not passed', () {
      final ReminderSchedule schedule = ReminderSchedule(prefs());
      // Wednesday 2026-01-07, 06:30.
      final DateTime next =
          schedule.nextOccurrenceAfter(DateTime(2026, 1, 7, 6, 30))!;
      expect(next, DateTime(2026, 1, 7, 8, 0));
    });

    test('rolls to tomorrow once the time has passed', () {
      final ReminderSchedule schedule = ReminderSchedule(prefs());
      final DateTime next =
          schedule.nextOccurrenceAfter(DateTime(2026, 1, 7, 8, 0))!;
      expect(next, DateTime(2026, 1, 8, 8, 0));
    });

    test('produces consecutive days', () {
      final List<DateTime> next = ReminderSchedule(prefs())
          .nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 3);
      expect(next, <DateTime>[
        DateTime(2026, 1, 8, 8, 0),
        DateTime(2026, 1, 9, 8, 0),
        DateTime(2026, 1, 10, 8, 0),
      ]);
    });
  });

  group('selected days', () {
    test('only fires on the chosen weekdays', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.selectedDays,
          weekdays: <int>{1, 3, 5},
        ),
      );
      // From Wednesday 2026-01-07 at 09:00 → Friday, Monday, Wednesday.
      final List<DateTime> next =
          schedule.nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 3);
      expect(next.map((DateTime d) => d.weekday), <int>[5, 1, 3]);
      expect(next.first, DateTime(2026, 1, 9, 8, 0));
    });

    test('never fires when no day is selected', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.selectedDays,
          weekdays: const <int>{},
        ),
      );
      expect(schedule.nextOccurrenceAfter(DateTime(2026, 1, 7)), isNull);
      expect(schedule.nextOccurrences(DateTime(2026, 1, 7)), isEmpty);
    });
  });

  group('weekly', () {
    test('fires once a week on the earliest selected day', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.weekly,
          // Several stored days collapse to one so the cadence is stable.
          weekdays: <int>{5, 2},
        ),
      );
      expect(schedule.activeWeekdays, <int>{2});
      final List<DateTime> next =
          schedule.nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 2);
      expect(next, <DateTime>[
        DateTime(2026, 1, 13, 8, 0),
        DateTime(2026, 1, 20, 8, 0),
      ]);
    });
  });

  group('every other day', () {
    test('skips a day between reminders', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.everyOtherDay,
          anchor: DateTime(2026, 1, 7),
        ),
      );
      final List<DateTime> next =
          schedule.nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 3);
      expect(next, <DateTime>[
        DateTime(2026, 1, 9, 8, 0),
        DateTime(2026, 1, 11, 8, 0),
        DateTime(2026, 1, 13, 8, 0),
      ]);
    });

    test('stays on cadence across a month boundary', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.everyOtherDay,
          anchor: DateTime(2026, 1, 30),
        ),
      );
      final List<DateTime> next =
          schedule.nextOccurrences(DateTime(2026, 1, 30, 9, 0), count: 2);
      expect(next, <DateTime>[
        DateTime(2026, 2, 1, 8, 0),
        DateTime(2026, 2, 3, 8, 0),
      ]);
    });
  });

  group('currentPeriodStart', () {
    test('is today once the reminder time has passed', () {
      final ReminderSchedule schedule = ReminderSchedule(prefs());
      expect(
        schedule.currentPeriodStart(DateTime(2026, 1, 7, 10, 0)),
        DateTime(2026, 1, 7, 8, 0),
      );
    });

    test('is yesterday before the reminder time', () {
      final ReminderSchedule schedule = ReminderSchedule(prefs());
      expect(
        schedule.currentPeriodStart(DateTime(2026, 1, 7, 6, 0)),
        DateTime(2026, 1, 6, 8, 0),
      );
    });

    test('follows the weekly cadence, not the calendar day', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(frequency: NotificationFrequency.weekly, weekdays: <int>{2}),
      );
      // Friday 2026-01-09: the period began on Tuesday the 6th.
      expect(
        schedule.currentPeriodStart(DateTime(2026, 1, 9, 12, 0)),
        DateTime(2026, 1, 6, 8, 0),
      );
    });

    test('falls back to a daily boundary when nothing can ever fire', () {
      // Reminders off / no days selected still needs a period so the book can
      // roll forward each day.
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.selectedDays,
          weekdays: const <int>{},
        ),
      );
      expect(
        schedule.currentPeriodStart(DateTime(2026, 1, 7, 10, 0)),
        DateTime(2026, 1, 7, 8, 0),
      );
      expect(
        schedule.currentPeriodStart(DateTime(2026, 1, 7, 6, 0)),
        DateTime(2026, 1, 6, 8, 0),
      );
    });
  });

  group('TimeOfDayValue', () {
    test('round-trips through storage', () {
      const TimeOfDayValue time = TimeOfDayValue(21, 5);
      expect(time.storageValue, '21:05');
      expect(TimeOfDayValue.parse('21:05'), time);
    });

    test('falls back to the default when malformed', () {
      for (final String? bad in <String?>[
        null,
        '',
        'abc',
        '25:00',
        '8:70',
        '8',
      ]) {
        expect(TimeOfDayValue.parse(bad), TimeOfDayValue.defaultTime);
      }
    });
  });

  group('several times a day', () {
    final List<TimeOfDayValue> threeTimes = <TimeOfDayValue>[
      const TimeOfDayValue(20, 0),
      const TimeOfDayValue(8, 0),
      const TimeOfDayValue(13, 30),
    ];

    test('times are kept earliest first, without duplicates', () {
      final NotificationPreferences preferences = prefs(
        times: <TimeOfDayValue>[...threeTimes, const TimeOfDayValue(8, 0)],
      );
      expect(preferences.times, const <TimeOfDayValue>[
        TimeOfDayValue(8, 0),
        TimeOfDayValue(13, 30),
        TimeOfDayValue(20, 0),
      ]);
      expect(preferences.time, const TimeOfDayValue(8, 0));
    });

    test('an empty list falls back to the default time', () {
      expect(prefs(times: const <TimeOfDayValue>[]).times,
          const <TimeOfDayValue>[TimeOfDayValue.defaultTime]);
    });

    test('fires at each time, in order, across days', () {
      final ReminderSchedule schedule =
          ReminderSchedule(prefs(times: threeTimes));
      expect(
        schedule.nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 4),
        <DateTime>[
          DateTime(2026, 1, 7, 13, 30),
          DateTime(2026, 1, 7, 20, 0),
          DateTime(2026, 1, 8, 8, 0),
          DateTime(2026, 1, 8, 13, 30),
        ],
      );
    });

    test('each reminder starts a new reading period', () {
      final ReminderSchedule schedule =
          ReminderSchedule(prefs(times: threeTimes));
      expect(schedule.currentPeriodStart(DateTime(2026, 1, 7, 7, 0)),
          DateTime(2026, 1, 6, 20, 0));
      expect(schedule.currentPeriodStart(DateTime(2026, 1, 7, 14, 0)),
          DateTime(2026, 1, 7, 13, 30));
      expect(schedule.currentPeriodStart(DateTime(2026, 1, 7, 23, 0)),
          DateTime(2026, 1, 7, 20, 0));
    });

    test('selected days fire at every time on those days only', () {
      final ReminderSchedule schedule = ReminderSchedule(
        prefs(
          frequency: NotificationFrequency.selectedDays,
          weekdays: <int>{5},
          times: <TimeOfDayValue>[
            const TimeOfDayValue(8, 0),
            const TimeOfDayValue(18, 0),
          ],
        ),
      );
      // Wednesday 2026-01-07; the next Friday is the 9th.
      expect(
        schedule.nextOccurrences(DateTime(2026, 1, 7, 9, 0), count: 3),
        <DateTime>[
          DateTime(2026, 1, 9, 8, 0),
          DateTime(2026, 1, 9, 18, 0),
          DateTime(2026, 1, 16, 8, 0),
        ],
      );
    });
  });
}
