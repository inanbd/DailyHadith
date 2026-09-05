/// Which language(s) of a hadith to render.
enum LanguageMode {
  english('english'),
  arabic('arabic'),
  both('both');

  const LanguageMode(this.storageKey);

  final String storageKey;

  bool get showsArabic => this != LanguageMode.english;
  bool get showsEnglish => this != LanguageMode.arabic;

  static LanguageMode fromStorage(String? value) {
    return LanguageMode.values.firstWhere(
      (LanguageMode mode) => mode.storageKey == value,
      orElse: () => LanguageMode.both,
    );
  }
}

/// Appearance preference. Mirrors [ThemeMode] but is persisted by the app.
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.storageKey);

  final String storageKey;

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (AppThemeMode mode) => mode.storageKey == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// Reading text size. Multiplies whatever the OS dynamic-type setting gives us
/// rather than replacing it, so platform accessibility settings still apply.
enum TextSizePreference {
  small('small', 0.9),
  standard('standard', 1.0),
  large('large', 1.15),
  extraLarge('extra_large', 1.3);

  const TextSizePreference(this.storageKey, this.scale);

  final String storageKey;
  final double scale;

  static TextSizePreference fromStorage(String? value) {
    return TextSizePreference.values.firstWhere(
      (TextSizePreference size) => size.storageKey == value,
      orElse: () => TextSizePreference.standard,
    );
  }
}

/// How often a reminder is delivered.
enum NotificationFrequency {
  daily('daily'),
  everyOtherDay('every_other_day'),
  selectedDays('selected_days'),
  weekly('weekly');

  const NotificationFrequency(this.storageKey);

  final String storageKey;

  static NotificationFrequency fromStorage(String? value) {
    return NotificationFrequency.values.firstWhere(
      (NotificationFrequency frequency) => frequency.storageKey == value,
      orElse: () => NotificationFrequency.daily,
    );
  }
}

/// Order in which hadith are delivered. Only [sequential] ships in the MVP;
/// [random] exists so the scheduling code has a seam to grow into.
enum ReadingOrder {
  sequential('sequential'),
  random('random');

  const ReadingOrder(this.storageKey);

  final String storageKey;

  static ReadingOrder fromStorage(String? value) {
    return ReadingOrder.values.firstWhere(
      (ReadingOrder order) => order.storageKey == value,
      orElse: () => ReadingOrder.sequential,
    );
  }
}

/// Provenance of a collection's text. Surfaced in the UI so development
/// fixtures can never be mistaken for verified hadith content.
enum ContentVerification {
  /// Text comes from a verified, attributed dataset.
  verified('verified'),

  /// Placeholder text used during development. Not hadith.
  developmentFixture('development_fixture');

  const ContentVerification(this.storageKey);

  final String storageKey;

  bool get isFixture => this == ContentVerification.developmentFixture;

  static ContentVerification fromStorage(String? value) {
    return ContentVerification.values.firstWhere(
      (ContentVerification status) => status.storageKey == value,
      orElse: () => ContentVerification.developmentFixture,
    );
  }
}
