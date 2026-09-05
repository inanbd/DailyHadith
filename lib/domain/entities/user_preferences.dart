import 'package:meta/meta.dart';

import 'enums.dart';

/// Reading and appearance preferences. Small enough to live in key-value
/// storage; nothing here is personal data.
@immutable
class UserPreferences {
  const UserPreferences({
    required this.languageMode,
    required this.themeMode,
    required this.textSize,
    required this.readingOrder,
    required this.onboardingComplete,
    this.currentCollectionId,
  });

  static const UserPreferences defaults = UserPreferences(
    languageMode: LanguageMode.both,
    themeMode: AppThemeMode.system,
    textSize: TextSizePreference.standard,
    readingOrder: ReadingOrder.sequential,
    onboardingComplete: false,
  );

  final LanguageMode languageMode;
  final AppThemeMode themeMode;
  final TextSizePreference textSize;
  final ReadingOrder readingOrder;
  final bool onboardingComplete;

  /// The book the Today screen reads from. Null before onboarding finishes.
  final String? currentCollectionId;

  UserPreferences copyWith({
    LanguageMode? languageMode,
    AppThemeMode? themeMode,
    TextSizePreference? textSize,
    ReadingOrder? readingOrder,
    bool? onboardingComplete,
    String? currentCollectionId,
  }) {
    return UserPreferences(
      languageMode: languageMode ?? this.languageMode,
      themeMode: themeMode ?? this.themeMode,
      textSize: textSize ?? this.textSize,
      readingOrder: readingOrder ?? this.readingOrder,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      currentCollectionId: currentCollectionId ?? this.currentCollectionId,
    );
  }
}
