import 'package:meta/meta.dart';

import '../entities/notification_preferences.dart';
import '../entities/reminder_readiness.dart';

// `NotificationPermissionStatus` and the requirements it describes are domain
// values, not implementation details, so they live with the entities. Re-
// exported here because everything that talks to a scheduler needs them.
export '../entities/reminder_readiness.dart';

/// Where a tapped notification should take the reader.
@immutable
class HadithDeepLink {
  const HadithDeepLink({required this.collectionId, this.ordinal});

  /// The collection the reminder was for.
  final String collectionId;

  /// The hadith the reminder showed, when it showed one. Tapping opens exactly
  /// that hadith, so what the reader saw is what they get. Null for a plain
  /// invitation, which opens the reader's current position instead.
  final int? ordinal;

  @override
  bool operator ==(Object other) =>
      other is HadithDeepLink &&
      other.collectionId == collectionId &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(collectionId, ordinal);

  @override
  String toString() => 'HadithDeepLink($collectionId, $ordinal)';
}

/// One reminder that carries the hadith it is for.
///
/// Planned by the app, which knows reading progress and random picks, and
/// armed by the scheduler, which knows only the platform.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.title,
    required this.body,
    required this.expandedBody,
    required this.link,
  });

  /// Wall-clock time; resolved against the device's timezone when armed.
  final DateTime at;

  final String title;

  /// A short excerpt, for the collapsed notification.
  final String body;

  /// A longer excerpt, for the expanded notification where the platform has
  /// one.
  final String expandedBody;

  final HadithDeepLink link;
}

/// Everything the app needs from the platform's local-notification support.
///
/// Scheduling is deliberately one-way: a reminder can only ever *invite* the
/// reader to open the app. Firing a notification never changes reading
/// progress.
abstract interface class NotificationScheduler {
  /// Prepares the plugin and timezone database. Safe to call more than once.
  Future<void> initialize();

  /// What the operating system is currently allowing.
  ///
  /// Re-read on every resume, because the reader may have changed any of it in
  /// system settings while the app was in the background.
  Future<ReminderReadiness> readiness();

  /// Raises the operating system's own prompt for [requirement] and reports
  /// whether it ended up granted.
  ///
  /// Only called once the reader has asked for reminders, so every prompt
  /// arrives with a reason the reader has already agreed to. Requirements the
  /// platform does not have return true — there is nothing to withhold.
  Future<bool> request(ReminderRequirement requirement);

  /// Opens this app's page in the system's notification settings.
  ///
  /// The escape hatch for a permission the OS will no longer prompt for: once
  /// notifications have been refused, [request] returns false without showing
  /// anything, and system settings is the only way back.
  ///
  /// Returns false when the platform could not open it.
  Future<bool> openSystemNotificationSettings();

  /// Cancels everything pending and re-arms from [preferences].
  ///
  /// Called whenever preferences change and on every app start, which is what
  /// keeps reminders correct across reboots, app updates, DST transitions and
  /// the reader travelling to a new timezone.
  ///
  /// When [planned] is not empty, exactly those reminders are armed — each one
  /// a single occurrence carrying its own hadith. Otherwise the cadence in
  /// [preferences] is armed as repeating invitations to open the app.
  Future<void> reschedule({
    required NotificationPreferences preferences,
    required String? collectionId,
    required String? collectionTitle,
    List<PlannedReminder> planned = const <PlannedReminder>[],
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
