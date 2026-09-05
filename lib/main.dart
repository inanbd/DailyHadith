import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/preferences_store.dart';
import 'domain/entities/notification_preferences.dart';
import 'domain/entities/user_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read before the first frame so the app opens straight into
  // the reader's chosen theme and book — no flash of the wrong theme, no
  // loading state for something this small.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final PreferencesStore store = PreferencesStore(prefs);
  final UserPreferences userPreferences = await store.loadUserPreferences();
  final NotificationPreferences notificationPreferences =
      await store.loadNotificationPreferences();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialUserPreferencesProvider.overrideWithValue(userPreferences),
        initialNotificationPreferencesProvider
            .overrideWithValue(notificationPreferences),
      ],
      child: const DailyHadithApp(),
    ),
  );
}
