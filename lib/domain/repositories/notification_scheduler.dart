import 'package:meta/meta.dart';

import '../entities/notification_preferences.dart';

/// Whether the operating system currently lets the app post notifications.
///
/// Kept separate from [NotificationPreferences.enabled]: the reader can want
/// reminders while the OS denies them, and the UI needs to say so plainly.
enum NotificationPermissionStatus {
  /// Permission granted.
  granted,

  /// Explicitly denied, or turned off in system settings.
  denied,

  /// Never asked. The app deliberately stays here until the reader has chosen
  /// a reminder time, so the OS prompt arrives with context.
  notDetermined,

  /// Platform does not support notifications.
  unsupported,
}

/// Where a tapped notification should take the reader.
@immutable
class HadithDeepLink {
  const HadithDeepLink({required this.collectionId});

  /// The collection the reminder was for. The reader is taken to their current
  /// position in it — never to a hadith chosen by the notification itself.
  final String collectionId;

  @override
  bool operator ==(Object other) =>
      other is HadithDeepLink && other.collectionId == collectionId;

  @override
  int get hashCode => collectionId.hashCode;
}

/// Everything the app needs from the platform's local-notification support.
///
/// Scheduling is deliberately one-way: a reminder can only ever *invite* the
/// reader to open the app. Firing a notification never changes reading
/// progress.
abstract interface class NotificationScheduler {
  /// Prepares the plugin and timezone database. Safe to call more than once.
  Future<void> initialize();

  Future<NotificationPermissionStatus> permissionStatus();

  /// Asks the OS for permission. Only called after the reader has chosen when
  /// they want to be reminded.
  Future<bool> requestPermission();

  /// Cancels everything pending and re-arms from [preferences].
  ///
  /// Called whenever preferences change and on every app start, which is what
  /// keeps reminders correct across reboots, app updates, DST transitions and
  /// the reader travelling to a new timezone.
  Future<void> reschedule({
    required NotificationPreferences preferences,
    required String? collectionId,
    required String? collectionTitle,
  });

  Future<void> cancelAll();

  /// The notification that launched the app, if any. Consumed once.
  Future<HadithDeepLink?> consumeLaunchDeepLink();

  /// Deep links from notifications tapped while the app is running.
  Stream<HadithDeepLink> get deepLinks;

  /// How many reminders the OS currently has armed for this app.
  ///
  /// Diagnostic only — the settings screen previews *upcoming* times from
  /// [ReminderSchedule], which is exact and does not depend on the platform.
  Future<int> pendingCount();
}
