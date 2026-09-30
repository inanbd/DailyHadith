import 'package:meta/meta.dart';

import 'enums.dart';

/// Time of day, stored independently of any date so it survives timezone
/// changes: 8:00 AM means 8:00 AM wherever the reader happens to be.
@immutable
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  const TimeOfDayValue(this.hour, this.minute);

  /// Parses `"HH:mm"`. Falls back to the default reminder time when malformed,
  /// so a corrupt preference can never break scheduling.
  factory TimeOfDayValue.parse(String? value) => tryParse(value) ?? defaultTime;

  /// Parses `"HH:mm"`, or returns null when [value] is missing or malformed.
  static TimeOfDayValue? tryParse(String? value) {
    if (value == null) return null;
    final List<String> parts = value.split(':');
    if (parts.length != 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDayValue(hour, minute);
  }

  static const TimeOfDayValue defaultTime = TimeOfDayValue(8, 0);

  final int hour;
  final int minute;

  String get storageValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  int get minutesFromMidnight => hour * 60 + minute;

  @override
  int compareTo(TimeOfDayValue other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => storageValue;
}

/// Reminder settings. Times are wall-clock; the scheduler resolves them
/// against the device's *current* timezone every time it schedules.
@immutable
class NotificationPreferences {
  /// [times] is normalised on the way in — sorted, without duplicates, and
  /// never empty — so everything downstream can rely on that.
  NotificationPreferences({
    required this.enabled,
    required this.frequency,
    required this.selectedWeekdays,
    required List<TimeOfDayValue> times,
    this.showHadithPreview = true,
    this.timezone,
    this.anchorDate,
  }) : times = normaliseTimes(times);

  const NotificationPreferences._defaults()
      : enabled = false,
        frequency = NotificationFrequency.daily,
        selectedWeekdays = const <int>{1, 2, 3, 4, 5, 6, 7},
        times = const <TimeOfDayValue>[TimeOfDayValue.defaultTime],
        showHadithPreview = true,
        timezone = null,
        anchorDate = null;

  static const NotificationPreferences defaults =
      NotificationPreferences._defaults();

  /// The most reminders a single day can carry. Keeps the number of alarms the
  /// OS is asked to hold well inside every platform's limit.
  static const int maxTimesPerDay = 6;

  /// Sorted, de-duplicated, capped at [maxTimesPerDay], and never empty.
  static List<TimeOfDayValue> normaliseTimes(Iterable<TimeOfDayValue> times) {
    final List<TimeOfDayValue> sorted = times.toSet().toList()..sort();
    if (sorted.isEmpty) return const <TimeOfDayValue>[TimeOfDayValue.defaultTime];
    return List<TimeOfDayValue>.unmodifiable(sorted.take(maxTimesPerDay));
  }

  /// Whether the reader has asked for reminders. Independent of whether the OS
  /// currently permits them.
  final bool enabled;

  final NotificationFrequency frequency;

  /// ISO weekdays (Mon = 1 … Sun = 7) used by
  /// [NotificationFrequency.selectedDays] and [NotificationFrequency.weekly].
  final Set<int> selectedWeekdays;

  /// Every time of day a reminder lands, earliest first. Each one starts a new
  /// reading period, so three times a day means up to three hadith a day.
  final List<TimeOfDayValue> times;

  /// The earliest reminder of the day.
  TimeOfDayValue get time => times.first;

  /// Whether a reminder carries the hadith it is for, rather than only an
  /// invitation to open the app.
  final bool showHadithPreview;

  /// The IANA zone last used to schedule. Recorded only so the app can notice
  /// the device moved and reschedule; it is never used to override the device.
  final String? timezone;

  /// Reference day for [NotificationFrequency.everyOtherDay], so the cadence
  /// stays stable across reschedules.
  final DateTime? anchorDate;

  NotificationPreferences copyWith({
    bool? enabled,
    NotificationFrequency? frequency,
    Set<int>? selectedWeekdays,
    List<TimeOfDayValue>? times,
    bool? showHadithPreview,
    String? timezone,
    DateTime? anchorDate,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      times: times ?? this.times,
      showHadithPreview: showHadithPreview ?? this.showHadithPreview,
      timezone: timezone ?? this.timezone,
      anchorDate: anchorDate ?? this.anchorDate,
    );
  }

  /// The weekdays a reminder can actually land on, given [frequency].
  Set<int> get effectiveWeekdays {
    switch (frequency) {
      case NotificationFrequency.daily:
      case NotificationFrequency.everyOtherDay:
        return const <int>{1, 2, 3, 4, 5, 6, 7};
      case NotificationFrequency.selectedDays:
      case NotificationFrequency.weekly:
        return selectedWeekdays;
    }
  }
}
