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
    this.randomCollectionIds = const <String>[],
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

  /// The books random mode draws from, as chosen by the reader. Empty until
  /// they choose; see [randomPool].
  final List<String> randomCollectionIds;

  /// The books random mode actually draws from: the reader's choice, or the
  /// current book when they have not made one.
  List<String> get randomPool {
    if (randomCollectionIds.isNotEmpty) return randomCollectionIds;
    final String? current = currentCollectionId;
    return current == null ? const <String>[] : <String>[current];
  }

  bool get isRandom => readingOrder == ReadingOrder.random;

  UserPreferences copyWith({
    LanguageMode? languageMode,
    AppThemeMode? themeMode,
    TextSizePreference? textSize,
    ReadingOrder? readingOrder,
    bool? onboardingComplete,
    String? currentCollectionId,
    List<String>? randomCollectionIds,
  }) {
    return UserPreferences(
      languageMode: languageMode ?? this.languageMode,
      themeMode: themeMode ?? this.themeMode,
      textSize: textSize ?? this.textSize,
      readingOrder: readingOrder ?? this.readingOrder,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      currentCollectionId: currentCollectionId ?? this.currentCollectionId,
      randomCollectionIds: randomCollectionIds ?? this.randomCollectionIds,
    );
  }
}
