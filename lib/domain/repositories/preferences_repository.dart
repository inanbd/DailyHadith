import '../entities/notification_preferences.dart';
import '../entities/user_preferences.dart';

/// Lightweight key-value preferences.
abstract interface class PreferencesRepository {
  Future<UserPreferences> loadUserPreferences();
  Future<void> saveUserPreferences(UserPreferences preferences);

  Future<NotificationPreferences> loadNotificationPreferences();
  Future<void> saveNotificationPreferences(NotificationPreferences preferences);
}
