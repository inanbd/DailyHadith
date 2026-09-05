import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/user_preferences.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/settings_group.dart';
import 'settings_labels.dart';

/// Theme and reading text size, with a preview that uses the real reading
/// styles so the choice is judged on the thing it affects.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final AppColors colors = context.colors;

    return AppPage(
      title: 'Appearance',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            title: 'Theme',
            children: <Widget>[
              for (final AppThemeMode mode in AppThemeMode.values)
                ChoiceRow<AppThemeMode>(
                  label: SettingsLabels.theme(mode),
                  value: mode,
                  groupValue: preferences.themeMode,
                  onChanged: (AppThemeMode value) => ref
                      .read(userPreferencesProvider.notifier)
                      .update(preferences.copyWith(themeMode: value)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Text size',
            children: <Widget>[
              for (final TextSizePreference size in TextSizePreference.values)
                ChoiceRow<TextSizePreference>(
                  label: SettingsLabels.textSize(size),
                  value: size,
                  groupValue: preferences.textSize,
                  onChanged: (TextSizePreference value) => ref
                      .read(userPreferencesProvider.notifier)
                      .update(preferences.copyWith(textSize: value)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Preview(scale: preferences.textSize.scale),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'This setting is applied on top of your device’s own text size, so '
            'system accessibility settings keep working.',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'PREVIEW',
            style: AppTypography.overline.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              // Sample text, not a hadith: the preview exists to judge size and
              // legibility only.
              'مثال لحجم النص العربي',
              locale: const Locale('ar'),
              style: AppTypography.arabicBody.copyWith(
                color: colors.textPrimary,
                fontSize: AppTypography.arabicBody.fontSize! * scale,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A sample line showing the English reading size.',
            style: AppTypography.englishBody.copyWith(
              color: colors.textPrimary,
              fontSize: AppTypography.englishBody.fontSize! * scale,
            ),
          ),
        ],
      ),
    );
  }
}
