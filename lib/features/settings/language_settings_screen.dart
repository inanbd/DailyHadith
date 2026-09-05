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

/// Which language(s) the hadith is shown in, with a live preview.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final AppColors colors = context.colors;

    return AppPage(
      title: 'Language',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            title: 'Hadith text',
            children: <Widget>[
              for (final LanguageMode mode in LanguageMode.values)
                ChoiceRow<LanguageMode>(
                  label: SettingsLabels.language(mode),
                  description: _description(mode),
                  value: mode,
                  groupValue: preferences.languageMode,
                  onChanged: (LanguageMode value) => ref
                      .read(userPreferencesProvider.notifier)
                      .update(preferences.copyWith(languageMode: value)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'When both are shown, Arabic is displayed first, followed by the '
            'translation.',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String? _description(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.english:
        return 'Translation only.';
      case LanguageMode.arabic:
        return 'Original Arabic only.';
      case LanguageMode.both:
        return 'Arabic first, then the translation.';
    }
  }
}
