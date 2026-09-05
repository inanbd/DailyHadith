import 'package:meta/meta.dart';

import 'enums.dart';

/// Time of day, stored independently of any date so it survives timezone
/// changes: 8:00 AM means 8:00 AM wherever the reader happens to be.
@immutable
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  const TimeOfDayValue(this.hour, this.minute);

  /// Parses `"HH:mm"`. Falls back to the default reminder time when malformed,
  /// so a corrupt preference can never break scheduling.
  factory TimeOfDayValue.parse(String? value) {
    if (value == null) return defaultTime;
    final List<String> parts = value.split(':');
    if (parts.length != 2) return defaultTime;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return defaultTime;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return defaultTime;
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
  const NotificationPreferences({
    required this.enabled,
    required this.frequency,
    required this.selectedWeekdays,
    required this.time,
    this.timezone,
    this.anchorDate,
  });

  static const NotificationPreferences defaults = NotificationPreferences(
    enabled: false,
    frequency: NotificationFrequency.daily,
    selectedWeekdays: <int>{1, 2, 3, 4, 5, 6, 7},
    time: TimeOfDayValue.defaultTime,
  );

  /// Whether the reader has asked for reminders. Independent of whether the OS
  /// currently permits them.
  final bool enabled;

  final NotificationFrequency frequency;

  /// ISO weekdays (Mon = 1 … Sun = 7) used by
  /// [NotificationFrequency.selectedDays] and [NotificationFrequency.weekly].
  final Set<int> selectedWeekdays;

  final TimeOfDayValue time;

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
    TimeOfDayValue? time,
    String? timezone,
    DateTime? anchorDate,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      time: time ?? this.time,
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
