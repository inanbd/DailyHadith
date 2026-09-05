import '../../core/utils/formatting.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/notification_preferences.dart';

/// Human-readable names for preference values. Kept in one place so the
/// settings hub and the detail screens can never drift apart.
abstract final class SettingsLabels {
  static String language(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.english:
        return 'English';
      case LanguageMode.arabic:
        return 'Arabic';
      case LanguageMode.both:
        return 'English + Arabic';
    }
  }

  static String theme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  static String textSize(TextSizePreference size) {
    switch (size) {
      case TextSizePreference.small:
        return 'Small';
      case TextSizePreference.standard:
        return 'Default';
      case TextSizePreference.large:
        return 'Large';
      case TextSizePreference.extraLarge:
        return 'Extra large';
    }
  }

  static String frequencyName(NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.daily:
        return 'Every day';
      case NotificationFrequency.everyOtherDay:
        return 'Every other day';
      case NotificationFrequency.selectedDays:
        return 'Selected days';
      case NotificationFrequency.weekly:
        return 'Weekly';
    }
  }

  /// Frequency including the specific days, e.g. "Selected days · Mon, Wed".
  static String frequency(NotificationPreferences preferences) {
    final String name = frequencyName(preferences.frequency);
    switch (preferences.frequency) {
      case NotificationFrequency.daily:
      case NotificationFrequency.everyOtherDay:
        return name;
      case NotificationFrequency.selectedDays:
        return '$name · ${Formatting.weekdayList(preferences.selectedWeekdays)}';
      case NotificationFrequency.weekly:
        if (preferences.selectedWeekdays.isEmpty) return name;
        final int day = preferences.selectedWeekdays.reduce(
          (int a, int b) => a < b ? a : b,
        );
        return '$name · ${Formatting.fullWeekday(day)}';
    }
  }
}
