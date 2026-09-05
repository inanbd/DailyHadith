import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/user_preferences.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/settings_group.dart';
import 'settings_labels.dart';

/// The settings hub. Each row either shows a value or opens a focused screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final NotificationPreferences notifications =
        ref.watch(notificationPreferencesProvider);
    final AsyncValue<HadithCollection?> current =
        ref.watch(currentCollectionProvider);
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    return AppPage(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            title: 'Reading',
            children: <Widget>[
              SettingsRow(
                label: 'Current book',
                value: current.value?.titleEnglish ?? 'Not chosen',
                onTap: () => context.go(Routes.library),
              ),
              SettingsRow(
                label: 'Language',
                value: SettingsLabels.language(preferences.languageMode),
                onTap: () => context.go(Routes.settingsLanguage),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Notifications',
            children: <Widget>[
              SettingsRow(
                label: 'Reminders',
                value: notifications.enabled ? 'On' : 'Off',
                onTap: () => context.go(Routes.settingsNotifications),
              ),
              SettingsRow(
                label: 'Frequency',
                value: SettingsLabels.frequency(notifications),
                onTap: () => context.go(Routes.settingsNotifications),
              ),
              SettingsRow(
                label: 'Time',
                value: Formatting.timeOfDay(
                  notifications.time.hour,
                  notifications.time.minute,
                  use24Hour: use24Hour,
                ),
                onTap: () => context.go(Routes.settingsNotifications),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Appearance',
            children: <Widget>[
              SettingsRow(
                label: 'Theme',
                value: SettingsLabels.theme(preferences.themeMode),
                onTap: () => context.go(Routes.settingsAppearance),
              ),
              SettingsRow(
                label: 'Text size',
                value: SettingsLabels.textSize(preferences.textSize),
                onTap: () => context.go(Routes.settingsAppearance),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'About',
            children: <Widget>[
              SettingsRow(
                label: 'Hadith sources',
                onTap: () => context.go(Routes.settingsAbout),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
