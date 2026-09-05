import 'package:flutter/material.dart';

/// Warm, paper-like palette for the app.
///
/// The light values come straight from the product's visual direction; the dark
/// values are tuned counterparts that keep the same warm neutral character.
/// Every foreground/background pair used for text meets WCAG AA (>= 4.5:1).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.warm,
    required this.danger,
  });

  /// Page background — the "paper".
  final Color background;

  /// Reading surface / cards.
  final Color surface;

  /// Slightly recessed surface for grouped rows.
  final Color surfaceMuted;

  /// Hadith text and headings. Contrast on [background] > 12:1.
  final Color textPrimary;

  /// Metadata, references, helper copy. Contrast on [background] >= 4.5:1.
  final Color textSecondary;

  /// Hairlines and separators. Structure comes from borders, not shadows.
  final Color border;

  /// The single brand accent.
  final Color accent;

  /// Tinted accent background for badges and progress tracks.
  final Color accentSoft;

  /// Foreground used on top of [accent].
  final Color onAccent;

  /// Restrained warm gold. Decorative only — never used as text on
  /// [background], where it would not reach AA.
  final Color warm;

  /// Reserved for destructive or blocked states.
  final Color danger;

  static const AppColors light = AppColors(
    background: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F1EB),
    textPrimary: Color(0xFF1C1C1A),
    textSecondary: Color(0xFF73736E),
    border: Color(0xFFE8E5DE),
    accent: Color(0xFF295F4E),
    accentSoft: Color(0xFFEAF2EE),
    onAccent: Color(0xFFFFFFFF),
    warm: Color(0xFFB48A4A),
    danger: Color(0xFF9C3B2E),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF121310),
    surface: Color(0xFF1A1B17),
    surfaceMuted: Color(0xFF212219),
    textPrimary: Color(0xFFF2F1EC),
    textSecondary: Color(0xFFA3A29A),
    border: Color(0xFF2C2D28),
    accent: Color(0xFF6FB39A),
    accentSoft: Color(0xFF1E2E28),
    onAccent: Color(0xFF08150F),
    warm: Color(0xFFC9A469),
    danger: Color(0xFFE08A7C),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? warm,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      warm: warm ?? this.warm,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// `context.colors` — the palette for the active theme.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
