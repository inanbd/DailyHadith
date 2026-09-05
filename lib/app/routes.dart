/// Every location in the app, in one place.
///
/// Plain strings rather than generated typed routes: the route set is small,
/// and keeping it dependency-free means notification payloads and tests can
/// build locations without pulling in code generation.
abstract final class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  static const String today = '/today';
  static const String library = '/library';
  static const String progress = '/progress';
  static const String settings = '/settings';

  static const String collectionSegment = 'collection';

  /// Details for one collection.
  static String collection(String collectionId) =>
      '$library/$collectionSegment/${Uri.encodeComponent(collectionId)}';

  static const String settingsNotifications = '$settings/notifications';
  static const String settingsLanguage = '$settings/language';
  static const String settingsAppearance = '$settings/appearance';
  static const String settingsAbout = '$settings/about';

  /// Tab order for the bottom navigation bar.
  static const List<String> tabs = <String>[today, library, progress, settings];
}
