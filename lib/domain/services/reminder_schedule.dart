import '../entities/enums.dart';
import '../entities/notification_preferences.dart';

/// Pure, timezone-free reminder maths.
///
/// Everything here works on *wall-clock* dates and times. The notification
/// scheduler converts the results into the device's current timezone at the
/// moment it schedules, which is what keeps "8:00 AM" meaning 8:00 AM across
/// DST transitions and travel.
class ReminderSchedule {
  const ReminderSchedule(this.preferences);

  final NotificationPreferences preferences;

  /// How far ahead [nextOccurrences] and the search helpers will look. Long
  /// enough for a weekly cadence, short enough to stay cheap.
  static const int _searchHorizonDays = 400;

  /// Days a reminder can land on, as ISO weekdays (Mon = 1 … Sun = 7).
  Set<int> get activeWeekdays {
    switch (preferences.frequency) {
      case NotificationFrequency.daily:
      case NotificationFrequency.everyOtherDay:
        return const <int>{1, 2, 3, 4, 5, 6, 7};
      case NotificationFrequency.selectedDays:
        return preferences.selectedWeekdays;
      case NotificationFrequency.weekly:
        if (preferences.selectedWeekdays.isEmpty) return const <int>{};
        // Weekly means one day a week; if several are stored, the earliest in
        // the week wins so the cadence is deterministic.
        return <int>{preferences.selectedWeekdays.reduce((int a, int b) => a < b ? a : b)};
    }
  }

  /// Whether a reminder falls on the calendar day containing [day].
  bool occursOn(DateTime day) {
    if (!activeWeekdays.contains(day.weekday)) return false;
    if (preferences.frequency != NotificationFrequency.everyOtherDay) {
      return true;
    }
    final DateTime anchor = preferences.anchorDate ?? day;
    // Compared in whole calendar days via UTC so a DST shift can never turn a
    // 24-hour gap into 23 and drop a day.
    final int delta = (_epochDay(day) - _epochDay(anchor)).abs();
    return delta.isEven;
  }

  /// The reminder date-time strictly after [from], or null if the settings can
  /// never fire (for example "selected days" with nothing selected).
  DateTime? nextOccurrenceAfter(DateTime from) {
    for (int offset = 0; offset <= _searchHorizonDays; offset++) {
      final DateTime day = _addDays(_dateOnly(from), offset);
      if (!occursOn(day)) continue;
      final DateTime candidate = _at(day, preferences.time);
      if (candidate.isAfter(from)) return candidate;
    }
    return null;
  }

  /// The next [count] reminder date-times after [from], in order.
  List<DateTime> nextOccurrences(DateTime from, {int count = 8}) {
    final List<DateTime> result = <DateTime>[];
    DateTime cursor = from;
    for (int i = 0; i < count; i++) {
      final DateTime? next = nextOccurrenceAfter(cursor);
      if (next == null) break;
      result.add(next);
      cursor = next;
    }
    return result;
  }

  /// The most recent reminder date-time at or before [moment], or null when
  /// there is none within the search horizon.
  DateTime? mostRecentOccurrenceAtOrBefore(DateTime moment) {
    for (int offset = 0; offset <= _searchHorizonDays; offset++) {
      final DateTime day = _addDays(_dateOnly(moment), -offset);
      if (!occursOn(day)) continue;
      final DateTime candidate = _at(day, preferences.time);
      if (!candidate.isAfter(moment)) return candidate;
    }
    return null;
  }

  /// Start of the reading period containing [now].
  ///
  /// Always returns a value: when the reminder settings themselves never fire,
  /// the period falls back to a plain daily boundary at the configured time, so
  /// the reader's book still rolls forward each day with reminders switched off.
  DateTime currentPeriodStart(DateTime now) {
    final DateTime? scheduled = mostRecentOccurrenceAtOrBefore(now);
    if (scheduled != null) return scheduled;
    final DateTime todayAtTime = _at(_dateOnly(now), preferences.time);
    if (!todayAtTime.isAfter(now)) return todayAtTime;
    return _at(_addDays(_dateOnly(now), -1), preferences.time);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Adds whole calendar days. Constructing a new [DateTime] rather than adding
  /// a [Duration] keeps the local wall-clock date correct across DST.
  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static DateTime _at(DateTime day, TimeOfDayValue time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  static int _epochDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
}
