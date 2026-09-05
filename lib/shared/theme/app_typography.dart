import 'package:flutter/material.dart';

/// Font families bundled with the app. Both are variable fonts shipped under
/// the SIL Open Font License (see `assets/fonts/`).
abstract final class AppFonts {
  static const String english = 'Inter';
  static const String arabic = 'NotoNaskhArabic';

  /// Fallbacks keep text readable if a glyph is missing from the bundled face.
  static const List<String> arabicFallback = <String>[
    'NotoNaskhArabic',
    'Geeza Pro',
    'Noto Sans Arabic',
  ];
}

/// Reading-first type scale.
///
/// Sizes are the *base* sizes; the user's text-size preference and the
/// platform's dynamic type setting are applied on top via [TextScaler], so
/// nothing here is a hard cap.
abstract final class AppTypography {
  /// Screen titles — "Today's Hadith", "Hadith Library".
  static const TextStyle pageTitle = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Collection name / "Book 1 · Hadith 24".
  static const TextStyle metadata = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Small caps-ish label above a group of settings.
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.6,
  );

  /// The Arabic hadith body. Generous size and leading are intentional.
  static const TextStyle arabicBody = TextStyle(
    fontFamily: AppFonts.arabic,
    fontFamilyFallback: AppFonts.arabicFallback,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 2.0,
  );

  /// The English translation body.
  static const TextStyle englishBody = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 17.5,
    fontWeight: FontWeight.w400,
    height: 1.72,
  );

  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Reference block under the hadith.
  static const TextStyle reference = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// "24 of 1,896 read".
  static const TextStyle progressMeta = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.english,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Arabic titles shown in the library, e.g. رياض الصالحين.
  static const TextStyle arabicTitle = TextStyle(
    fontFamily: AppFonts.arabic,
    fontFamilyFallback: AppFonts.arabicFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.7,
  );
}
