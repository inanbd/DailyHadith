/// Spacing scale. Structure in this app comes from whitespace and hairlines,
/// so the scale is deliberately small and used consistently.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 20;

  /// Maximum width of a reading column. Keeps line length comfortable on
  /// tablets and large phones instead of stretching edge to edge.
  static const double readingMaxWidth = 640;

  /// Minimum tap target, per platform accessibility guidance.
  static const double minTapTarget = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
}
