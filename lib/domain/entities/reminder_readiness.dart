import 'package:meta/meta.dart';

/// Whether the operating system currently allows something reminders depend on.
///
/// Kept separate from `NotificationPreferences.enabled`: the reader can want
/// reminders while the OS withholds them, and the UI needs to say so plainly.
enum NotificationPermissionStatus {
  /// The OS allows it.
  granted,

  /// Refused, or turned off in system settings.
  denied,

  /// Never asked, or the platform cannot tell us. Treated as "worth asking".
  notDetermined,

  /// Does not exist on this platform or OS version, so nothing to ask for.
  /// Treated as satisfied — there is no prompt that would improve matters.
  unsupported,
}

/// One thing the operating system controls that a daily reminder depends on.
///
/// Only [notifications] decides whether a reminder can arrive at all. The other
/// two decide whether it arrives *when it was asked for*: Android is free to
/// defer an inexact alarm to whenever it next wakes the device, and a phone
/// that has put the app to sleep can drop the alarm altogether. Both are
/// nothing-to-ask-for on iOS, which delivers scheduled notifications itself.
enum ReminderRequirement {
  /// Permission to post notifications. Without it nothing arrives.
  notifications,

  /// Permission to schedule an alarm that fires at the chosen minute rather
  /// than whenever the system next feels like it.
  exactTiming,

  /// Exemption from battery optimisation, so the phone stops putting the app
  /// to sleep and cancelling its pending alarms.
  background,
}

/// What the operating system is currently allowing, requirement by requirement.
///
/// The app reads this rather than a single yes/no, because "reminders are on
/// but arrive two hours late" and "reminders never arrive" are different
/// problems with different fixes, and the reader can only fix what they are
/// told about.
@immutable
class ReminderReadiness {
  const ReminderReadiness({
    required this.notifications,
    required this.exactTiming,
    required this.background,
  });

  /// Before the platform has been asked. Never shown as a problem — the UI
  /// waits for the real answer rather than accusing the OS of blocking us.
  static const ReminderReadiness unknown = ReminderReadiness(
    notifications: NotificationPermissionStatus.notDetermined,
    exactTiming: NotificationPermissionStatus.notDetermined,
    background: NotificationPermissionStatus.notDetermined,
  );

  /// A platform with no notification support at all.
  static const ReminderReadiness unsupported = ReminderReadiness(
    notifications: NotificationPermissionStatus.unsupported,
    exactTiming: NotificationPermissionStatus.unsupported,
    background: NotificationPermissionStatus.unsupported,
  );

  final NotificationPermissionStatus notifications;
  final NotificationPermissionStatus exactTiming;
  final NotificationPermissionStatus background;

  NotificationPermissionStatus statusOf(ReminderRequirement requirement) {
    switch (requirement) {
      case ReminderRequirement.notifications:
        return notifications;
      case ReminderRequirement.exactTiming:
        return exactTiming;
      case ReminderRequirement.background:
        return background;
    }
  }

  /// True when there is a prompt worth raising for [requirement].
  bool needs(ReminderRequirement requirement) {
    switch (statusOf(requirement)) {
      case NotificationPermissionStatus.granted:
      case NotificationPermissionStatus.unsupported:
        return false;
      case NotificationPermissionStatus.denied:
      case NotificationPermissionStatus.notDetermined:
        return true;
    }
  }

  /// Everything still worth asking the reader about, in the order it should be
  /// asked: permission to arrive at all, then to arrive on time.
  List<ReminderRequirement> get outstanding => <ReminderRequirement>[
        for (final ReminderRequirement requirement in ReminderRequirement.values)
          if (needs(requirement)) requirement,
      ];

  /// Nothing will arrive until the reader changes this in system settings.
  bool get isBlocked => notifications == NotificationPermissionStatus.denied;

  /// Reminders can arrive, but the OS may hold them back or drop them.
  bool get isUnreliable =>
      !isBlocked &&
      (needs(ReminderRequirement.exactTiming) ||
          needs(ReminderRequirement.background));

  /// Everything the OS can grant has been granted.
  bool get isReady => outstanding.isEmpty;

  ReminderReadiness copyWith({
    NotificationPermissionStatus? notifications,
    NotificationPermissionStatus? exactTiming,
    NotificationPermissionStatus? background,
  }) {
    return ReminderReadiness(
      notifications: notifications ?? this.notifications,
      exactTiming: exactTiming ?? this.exactTiming,
      background: background ?? this.background,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderReadiness &&
      other.notifications == notifications &&
      other.exactTiming == exactTiming &&
      other.background == background;

  @override
  int get hashCode => Object.hash(notifications, exactTiming, background);

  @override
  String toString() => 'ReminderReadiness(notifications: $notifications, '
      'exactTiming: $exactTiming, background: $background)';
}
