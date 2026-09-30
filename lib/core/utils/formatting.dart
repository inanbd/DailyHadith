import 'package:intl/intl.dart';

/// Shared, locale-aware formatting helpers.
abstract final class Formatting {
  static final NumberFormat _integer = NumberFormat.decimalPattern();
  static final DateFormat _mediumDate = DateFormat.yMMMd();

  /// `1896` → `1,896`.
  static String count(int value) => _integer.format(value);

  /// `Jan 12, 2026`.
  static String date(DateTime value) => _mediumDate.format(value);

  /// `12.8%`, or `13%` when the fraction adds nothing.
  static String percent(double percentage) {
    if (percentage == percentage.roundToDouble()) {
      return '${percentage.round()}%';
    }
    return '${percentage.toStringAsFixed(1)}%';
  }

  /// `8:00 AM`, honouring the device's 12/24-hour setting.
  static String timeOfDay(int hour, int minute, {required bool use24Hour}) {
    final DateTime moment = DateTime(2000, 1, 1, hour, minute);
    return DateFormat(use24Hour ? 'HH:mm' : 'h:mm a').format(moment);
  }

  /// `Mon`, `Tue`, … for an ISO weekday (1–7).
  static String shortWeekday(int isoWeekday) {
    // 2024-01-01 was a Monday, so this maps 1→Mon … 7→Sun.
    return DateFormat.E().format(DateTime(2024, 1, isoWeekday));
  }

  /// `Monday`, `Tuesday`, … for an ISO weekday (1–7).
  static String fullWeekday(int isoWeekday) {
    return DateFormat.EEEE().format(DateTime(2024, 1, isoWeekday));
  }

  /// Human phrasing for a set of weekdays: "Every day", "Weekdays",
  /// "Mon, Wed, Fri".
  static String weekdayList(Set<int> weekdays) {
    if (weekdays.isEmpty) return 'No days selected';
    if (weekdays.length == 7) return 'Every day';
    const Set<int> workdays = <int>{1, 2, 3, 4, 5};
    if (weekdays.length == 5 && weekdays.containsAll(workdays)) {
      return 'Weekdays';
    }
    if (weekdays.length == 2 && weekdays.containsAll(<int>{6, 7})) {
      return 'Weekends';
    }
    final List<int> sorted = weekdays.toList()..sort();
    return sorted.map(shortWeekday).join(', ');
  }

  /// The opening of [text], at most [maxLength] characters, cut at a word
  /// boundary and marked with an ellipsis when anything was left out.
  ///
  /// Line breaks and runs of spaces are collapsed first, because the excerpt
  /// is for a single notification line. Only ever used for previews that link
  /// to the full text — never in place of it.
  static String excerpt(String text, int maxLength) {
    final String flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= maxLength) return flat;
    final String cut = flat.substring(0, maxLength);
    final int lastSpace = cut.lastIndexOf(' ');
    final String head =
        lastSpace > maxLength ~/ 2 ? cut.substring(0, lastSpace) : cut;
    return '${head.trimRight()}…';
  }
}
