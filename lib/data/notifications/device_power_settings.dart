import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The two things Android controls that `flutter_local_notifications` cannot
/// reach: battery optimisation, and the door back into system settings.
///
/// Battery optimisation is the reason a reminder that was scheduled correctly
/// still never arrives. Android — and, far more aggressively, several
/// manufacturer skins on top of it — will put an app it considers idle to
/// sleep and drop its pending alarms with it. Asking for the exemption raises
/// the system's own "Allow app to always run in the background?" dialog; the
/// reader decides, and the app carries on either way.
///
/// Every method is best-effort. On iOS, on a platform without the host side
/// registered, or if the OS simply refuses, the call reports "no" rather than
/// throwing: reminders are an accessory, and reading must never break because
/// a power setting could not be read.
class DevicePowerSettings {
  const DevicePowerSettings({this._channel = _defaultChannel});

  static const MethodChannel _defaultChannel =
      MethodChannel('com.i9tech.dailyhadith/power');

  final MethodChannel _channel;

  /// Whether the app is already exempt from battery optimisation.
  ///
  /// Null when the platform cannot answer, which the caller reports as
  /// "unsupported" rather than as a problem the reader should fix.
  Future<bool?> isExemptFromBatteryOptimisation() =>
      _invoke<bool>('isIgnoringBatteryOptimizations');

  /// Raises the system dialog asking for the exemption, and reports the state
  /// after the reader has answered.
  Future<bool> requestBatteryOptimisationExemption() async =>
      await _invoke<bool>('requestIgnoreBatteryOptimizations') ?? false;

  /// Opens this app's notification settings. The way back once notifications
  /// have been refused and the OS will no longer prompt.
  Future<bool> openNotificationSettings() async =>
      await _invoke<bool>('openNotificationSettings') ?? false;

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      // Not Android, or the host side is not registered. Nothing to report.
      return null;
    } on PlatformException catch (error) {
      debugPrint('Daily Hadith: $method failed (${error.code})');
      return null;
    }
  }
}
