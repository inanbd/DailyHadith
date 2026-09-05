import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/enums.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_scheduler.dart';
import '../../domain/services/reminder_schedule.dart';

/// Handles a notification tapped while the app was terminated or in the
/// background. Must be a top-level function so the platform can find it.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // Nothing to do here: the tap is delivered again through
  // `getNotificationAppLaunchDetails` when the UI isolate starts, and reading
  // progress must never change without the reader opening the hadith.
}

/// [NotificationScheduler] backed by `flutter_local_notifications`.
///
/// ## How reminders stay correct
///
/// Times are stored as wall-clock values and resolved against the device's
/// *current* timezone every time we schedule, so travelling or a DST change
/// keeps 8:00 AM at 8:00 AM.
///
/// Daily, weekly and selected-day cadences are armed as OS-level repeating
/// notifications, which survive reboots and app updates without the app
/// running. Every-other-day has no repeating equivalent, so a rolling window of
/// concrete occurrences is armed instead and topped up on each app start.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<HadithDeepLink> _deepLinks =
      StreamController<HadithDeepLink>.broadcast();

  bool _initialized = false;
  bool _launchLinkConsumed = false;

  static const String channelId = 'daily_hadith_reminders';
  static const String channelName = 'Reading reminders';
  static const String channelDescription =
      'A gentle prompt when your next hadith is ready to read.';

  /// Id of the single repeating daily reminder.
  static const int _dailyId = 1000;

  /// Weekly / selected-day reminders occupy 1001–1007 (one per ISO weekday).
  static const int _weekdayIdBase = 1000;

  /// Every-other-day occurrences occupy 1100 upwards.
  static const int _intervalIdBase = 1100;

  /// How many every-other-day occurrences to keep armed — roughly two months,
  /// re-armed whenever the app runs.
  static const int _intervalWindow = 30;

  @override
  Stream<HadithDeepLink> get deepLinks => _deepLinks.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    await _initializeTimezone();

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // All three permission requests are off: the OS prompt is raised later,
    // once the reader has picked a reminder time and knows why we are asking.
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.defaultImportance,
          ),
        );

    _initialized = true;
  }

  /// Loads the timezone database and points it at the device's zone.
  ///
  /// Called on every [initialize] and every [reschedule] so a device that
  /// changed timezone is picked up without a reinstall. Falls back to UTC
  /// rather than throwing — a reminder at the wrong hour beats a crash.
  Future<void> _initializeTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Object catch (error) {
      debugPrint('Daily Hadith: falling back to UTC for reminders ($error)');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  void _handleResponse(NotificationResponse response) {
    final HadithDeepLink? link = _parsePayload(response.payload);
    if (link != null) _deepLinks.add(link);
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool? enabled = await android.areNotificationsEnabled();
      if (enabled == null) return NotificationPermissionStatus.notDetermined;
      return enabled
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final NotificationsEnabledOptions? options = await ios.checkPermissions();
      if (options == null) return NotificationPermissionStatus.notDetermined;
      return options.isEnabled
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    return NotificationPermissionStatus.unsupported;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> reschedule({
    required NotificationPreferences preferences,
    required String? collectionId,
    required String? collectionTitle,
  }) async {
    await initialize();
    // Re-resolve the device zone: this is the moment a timezone change or a
    // DST boundary gets picked up.
    await _initializeTimezone();

    // Always start from a clean slate so a frequency change can never leave a
    // stale reminder armed.
    await _plugin.cancelAll();

    if (!preferences.enabled) return;
    if (await permissionStatus() != NotificationPermissionStatus.granted) return;

    const String title = 'Today’s Hadith';
    final String body = collectionTitle == null
        ? 'Your next hadith is ready.'
        : 'Your next hadith from $collectionTitle is ready.';
    final String payload = jsonEncode(<String, Object?>{
      'type': 'reminder',
      'collectionId': collectionId,
    });

    switch (preferences.frequency) {
      case NotificationFrequency.daily:
        await _scheduleRepeating(
          id: _dailyId,
          first: _nextInstanceOfTime(preferences.time),
          match: DateTimeComponents.time,
          title: title,
          body: body,
          payload: payload,
        );
      case NotificationFrequency.selectedDays:
      case NotificationFrequency.weekly:
        final Set<int> weekdays =
            ReminderSchedule(preferences).activeWeekdays;
        for (final int weekday in weekdays) {
          await _scheduleRepeating(
            id: _weekdayIdBase + weekday,
            first: _nextInstanceOfWeekday(weekday, preferences.time),
            match: DateTimeComponents.dayOfWeekAndTime,
            title: title,
            body: body,
            payload: payload,
          );
        }
      case NotificationFrequency.everyOtherDay:
        // No repeating rule matches "every other day", so a window of concrete
        // occurrences is armed and topped up whenever the app runs.
        final List<DateTime> occurrences = ReminderSchedule(preferences)
            .nextOccurrences(DateTime.now(), count: _intervalWindow);
        for (int index = 0; index < occurrences.length; index++) {
          await _scheduleRepeating(
            id: _intervalIdBase + index,
            first: _toTz(occurrences[index]),
            match: null,
            title: title,
            body: body,
            payload: payload,
          );
        }
    }
  }

  Future<void> _scheduleRepeating({
    required int id,
    required tz.TZDateTime first,
    required DateTimeComponents? match,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      first,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // The hadith itself is never put in the notification — the reminder
          // only invites the reader to open the app.
          styleInformation: DefaultStyleInformation(false, false),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      // Inexact alarms are the right fit for a gentle reading reminder and,
      // unlike exact alarms, need no special permission on Android 12+.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: match,
    );
  }

  @override
  Future<HadithDeepLink?> consumeLaunchDeepLink() async {
    if (_launchLinkConsumed) return null;
    _launchLinkConsumed = true;
    await initialize();
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return _parsePayload(details.notificationResponse?.payload);
  }

  @override
  Future<int> pendingCount() async {
    await initialize();
    final List<PendingNotificationRequest> pending =
        await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  static HadithDeepLink? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) return null;
      final Object? collectionId = decoded['collectionId'];
      if (collectionId is! String || collectionId.isEmpty) return null;
      return HadithDeepLink(collectionId: collectionId);
    } on FormatException {
      return null;
    }
  }

  static tz.TZDateTime _toTz(DateTime value) => tz.TZDateTime(
        tz.local,
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
      );

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDayValue time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = _plusDays(scheduled, 1);
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceOfWeekday(
    int weekday,
    TimeOfDayValue time,
  ) {
    tz.TZDateTime scheduled = _nextInstanceOfTime(time);
    while (scheduled.weekday != weekday) {
      scheduled = _plusDays(scheduled, 1);
    }
    return scheduled;
  }

  /// Adds whole calendar days while holding the wall-clock time steady.
  ///
  /// Adding a [Duration] would shift the hour across a DST boundary; rebuilding
  /// the date keeps "8:00 AM" at 8:00 AM.
  static tz.TZDateTime _plusDays(tz.TZDateTime value, int days) =>
      tz.TZDateTime(
        tz.local,
        value.year,
        value.month,
        value.day + days,
        value.hour,
        value.minute,
      );

  Future<void> dispose() async => _deepLinks.close();
}
