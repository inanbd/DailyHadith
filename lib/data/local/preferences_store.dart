import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// Key-value preference storage.
///
/// Only small, non-personal settings live here; reading data belongs in
/// SQLite. Every read is defensive: a missing or malformed value falls back to
/// the documented default rather than throwing.
class PreferencesStore implements PreferencesRepository {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kLanguageMode = 'pref.language_mode';
  static const String _kThemeMode = 'pref.theme_mode';
  static const String _kTextSize = 'pref.text_size';
  static const String _kReadingOrder = 'pref.reading_order';
  static const String _kOnboardingComplete = 'pref.onboarding_complete';
  static const String _kCurrentCollection = 'pref.current_collection_id';
  static const String _kRandomCollections = 'pref.random_collection_ids';

  static const String _kNotifyEnabled = 'notify.enabled';
  static const String _kNotifyFrequency = 'notify.frequency';
  static const String _kNotifyWeekdays = 'notify.weekdays';
  /// Written alongside [_kNotifyTimes] as the earliest time, so a downgrade to
  /// a build that knows only one time still finds a valid value.
  static const String _kNotifyTime = 'notify.time';
  static const String _kNotifyTimes = 'notify.times';
  static const String _kNotifyPreview = 'notify.show_preview';
  static const String _kNotifyTimezone = 'notify.timezone';
  static const String _kNotifyAnchor = 'notify.anchor_date';

  @override
  Future<UserPreferences> loadUserPreferences() async {
    return UserPreferences(
      languageMode: LanguageMode.fromStorage(_prefs.getString(_kLanguageMode)),
      themeMode: AppThemeMode.fromStorage(_prefs.getString(_kThemeMode)),
      textSize: TextSizePreference.fromStorage(_prefs.getString(_kTextSize)),
      readingOrder: ReadingOrder.fromStorage(_prefs.getString(_kReadingOrder)),
      onboardingComplete: _prefs.getBool(_kOnboardingComplete) ?? false,
      currentCollectionId: _prefs.getString(_kCurrentCollection),
      randomCollectionIds:
          _prefs.getStringList(_kRandomCollections) ?? const <String>[],
    );
  }

  @override
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await _prefs.setString(_kLanguageMode, preferences.languageMode.storageKey);
    await _prefs.setString(_kThemeMode, preferences.themeMode.storageKey);
    await _prefs.setString(_kTextSize, preferences.textSize.storageKey);
    await _prefs.setString(_kReadingOrder, preferences.readingOrder.storageKey);
    await _prefs.setBool(_kOnboardingComplete, preferences.onboardingComplete);
    final String? collectionId = preferences.currentCollectionId;
    if (collectionId == null) {
      await _prefs.remove(_kCurrentCollection);
    } else {
      await _prefs.setString(_kCurrentCollection, collectionId);
    }
    await _prefs.setStringList(
      _kRandomCollections,
      preferences.randomCollectionIds,
    );
  }

  @override
  Future<NotificationPreferences> loadNotificationPreferences() async {
    final List<String>? weekdays = _prefs.getStringList(_kNotifyWeekdays);
    final int? anchor = _prefs.getInt(_kNotifyAnchor);
    return NotificationPreferences(
      enabled: _prefs.getBool(_kNotifyEnabled) ?? false,
      frequency:
          NotificationFrequency.fromStorage(_prefs.getString(_kNotifyFrequency)),
      selectedWeekdays: _parseWeekdays(weekdays),
      times: _parseTimes(
        _prefs.getStringList(_kNotifyTimes),
        _prefs.getString(_kNotifyTime),
      ),
      showHadithPreview: _prefs.getBool(_kNotifyPreview) ?? true,
      timezone: _prefs.getString(_kNotifyTimezone),
      anchorDate:
          anchor == null ? null : DateTime.fromMillisecondsSinceEpoch(anchor),
    );
  }

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    await _prefs.setBool(_kNotifyEnabled, preferences.enabled);
    await _prefs.setString(
      _kNotifyFrequency,
      preferences.frequency.storageKey,
    );
    await _prefs.setStringList(
      _kNotifyWeekdays,
      preferences.selectedWeekdays
          .map((int day) => day.toString())
          .toList(growable: false),
    );
    await _prefs.setString(_kNotifyTime, preferences.time.storageValue);
    await _prefs.setStringList(
      _kNotifyTimes,
      preferences.times
          .map((TimeOfDayValue time) => time.storageValue)
          .toList(growable: false),
    );
    await _prefs.setBool(_kNotifyPreview, preferences.showHadithPreview);
    final String? timezone = preferences.timezone;
    if (timezone == null) {
      await _prefs.remove(_kNotifyTimezone);
    } else {
      await _prefs.setString(_kNotifyTimezone, timezone);
    }
    final DateTime? anchor = preferences.anchorDate;
    if (anchor == null) {
      await _prefs.remove(_kNotifyAnchor);
    } else {
      await _prefs.setInt(_kNotifyAnchor, anchor.millisecondsSinceEpoch);
    }
  }

  /// Reminder times, falling back to the single time stored by earlier
  /// versions. Malformed entries are dropped rather than replaced, so one bad
  /// value cannot turn into an extra 8:00 AM reminder.
  static List<TimeOfDayValue> _parseTimes(List<String>? raw, String? legacy) {
    final List<TimeOfDayValue> parsed = <TimeOfDayValue>[
      for (final String value in raw ?? const <String>[])
        if (TimeOfDayValue.tryParse(value) case final TimeOfDayValue time) time,
    ];
    if (parsed.isNotEmpty) return parsed;
    return <TimeOfDayValue>[TimeOfDayValue.parse(legacy)];
  }

  static Set<int> _parseWeekdays(List<String>? raw) {
    if (raw == null) return NotificationPreferences.defaults.selectedWeekdays;
    final Set<int> parsed = raw
        .map(int.tryParse)
        .whereType<int>()
        .where((int day) => day >= 1 && day <= 7)
        .toSet();
    return parsed.isEmpty
        ? NotificationPreferences.defaults.selectedWeekdays
        : parsed;
  }
}
