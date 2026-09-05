import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_scheduler.dart';
import '../../features/today/today_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/settings_group.dart';
import '../../shared/widgets/state_views.dart';
import '../settings/settings_labels.dart';

/// Three short steps: why, which book, when.
///
/// No account, no permission prompt on launch. The OS notification prompt is
/// raised at the end of step three, once the reader has said when they want to
/// be reminded and can see why it is being asked for.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const String _recommendedCollectionId = 'riyad_as_salihin';

  int _step = 0;
  String? _collectionId;
  bool _remindersEnabled = true;
  NotificationFrequency _frequency = NotificationFrequency.daily;
  Set<int> _weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
  TimeOfDayValue _time = TimeOfDayValue.defaultTime;
  LanguageMode _language = LanguageMode.both;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<HadithCollection>> collections =
        ref.watch(browsableCollectionsProvider);

    return AppPage(
      title: _title,
      subtitle: 'Step ${_step + 1} of 3',
      child: switch (_step) {
        0 => _WelcomeStep(onContinue: () => setState(() => _step = 1)),
        1 => _ChooseBookStep(
            collections: collections,
            selectedId: _resolveSelection(collections.value),
            onSelected: (String id) => setState(() => _collectionId = id),
            onContinue: _resolveSelection(collections.value) == null
                ? null
                : () => setState(() => _step = 2),
            onBack: () => setState(() => _step = 0),
          ),
        _ => _ReminderStep(
            remindersEnabled: _remindersEnabled,
            frequency: _frequency,
            weekdays: _weekdays,
            time: _time,
            language: _language,
            saving: _saving,
            onRemindersChanged: (bool value) =>
                setState(() => _remindersEnabled = value),
            onFrequencyChanged: (NotificationFrequency value) =>
                setState(() => _frequency = value),
            onWeekdaysChanged: (Set<int> value) =>
                setState(() => _weekdays = value),
            onTimeChanged: (TimeOfDayValue value) =>
                setState(() => _time = value),
            onLanguageChanged: (LanguageMode value) =>
                setState(() => _language = value),
            onBack: () => setState(() => _step = 1),
            onFinish: () => _finish(collections.value),
          ),
      },
    );
  }

  String get _title {
    switch (_step) {
      case 0:
        return 'A Hadith at a time';
      case 1:
        return 'Choose your book';
      default:
        return 'Choose your reminder';
    }
  }

  /// The chosen book, defaulting to the recommended one when it can be read and
  /// otherwise to the first readable collection.
  String? _resolveSelection(List<HadithCollection>? collections) {
    final String? chosen = _collectionId;
    if (chosen != null) return chosen;
    if (collections == null || collections.isEmpty) return null;

    for (final HadithCollection collection in collections) {
      if (collection.id == _recommendedCollectionId && collection.isReadable) {
        return collection.id;
      }
    }
    for (final HadithCollection collection in collections) {
      if (collection.isReadable) return collection.id;
    }
    return null;
  }

  Future<void> _finish(List<HadithCollection>? collections) async {
    final String? collectionId = _resolveSelection(collections);
    if (collectionId == null || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(userPreferencesProvider.notifier).update(
            ref.read(userPreferencesProvider).copyWith(
                  languageMode: _language,
                  currentCollectionId: collectionId,
                  onboardingComplete: true,
                ),
          );

      if (_remindersEnabled) {
        // The permission prompt lands here — after the reader has picked a
        // time, never on first launch.
        final NotificationScheduler scheduler =
            ref.read(notificationSchedulerProvider);
        final NotificationPermissionStatus status =
            await scheduler.permissionStatus();
        if (status == NotificationPermissionStatus.notDetermined) {
          await scheduler.requestPermission();
        }
      }

      // Saving notification preferences also arms (or clears) the reminders.
      await ref.read(notificationPreferencesProvider.notifier).update(
            NotificationPreferences(
              enabled: _remindersEnabled,
              frequency: _frequency,
              selectedWeekdays: _weekdays,
              time: _time,
              anchorDate: DateTime.now(),
            ),
          );

      await ref.read(todayControllerProvider.notifier).refresh();
      if (mounted) context.go(Routes.today);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Build a consistent habit by reading from a hadith collection at '
          'your own pace.',
          style: AppTypography.englishBody.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'One hadith at a time, at the time that works best for you. Your '
          'place is saved, and nothing is marked read unless you read it.',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
      ],
    );
  }
}

class _ChooseBookStep extends StatelessWidget {
  const _ChooseBookStep({
    required this.collections,
    required this.selectedId,
    required this.onSelected,
    required this.onContinue,
    required this.onBack,
  });

  final AsyncValue<List<HadithCollection>> collections;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return collections.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => const ErrorStateView(
        title: 'The library could not be loaded',
        message:
            'The list of collections is missing. Reinstalling the app '
            'restores it.',
      ),
      data: (List<HadithCollection> value) {
        final List<HadithCollection> readable =
            value.where((HadithCollection c) => c.isReadable).toList();
        if (readable.isEmpty) {
          return const ErrorStateView(
            title: 'No collections are installed',
            message:
                'No hadith data has been added to this build of the app yet.',
            detail: 'See DATA_SOURCES.md for how to import a verified dataset.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'You can change this at any time, and each book keeps its own '
              'place.',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(
              title: 'Collections',
              children: <Widget>[
                for (final HadithCollection collection in readable)
                  ChoiceRow<String>(
                    label: collection.titleEnglish,
                    description: _describe(collection),
                    value: collection.id,
                    groupValue: selectedId ?? '',
                    onChanged: onSelected,
                  ),
              ],
            ),
            if (value.length > readable.length) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              const NoticeBanner(
                message:
                    'Some collections in the catalog have no text installed '
                    'yet and are not listed here.',
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        );
      },
    );
  }

  static String _describe(HadithCollection collection) {
    final StringBuffer buffer = StringBuffer();
    if (collection.compiler.isNotEmpty) buffer.write('${collection.compiler} · ');
    buffer.write('${Formatting.count(collection.totalHadith)} hadith');
    if (collection.isFixture) buffer.write(' · development data, not hadith');
    return buffer.toString();
  }
}

class _ReminderStep extends StatelessWidget {
  const _ReminderStep({
    required this.remindersEnabled,
    required this.frequency,
    required this.weekdays,
    required this.time,
    required this.language,
    required this.saving,
    required this.onRemindersChanged,
    required this.onFrequencyChanged,
    required this.onWeekdaysChanged,
    required this.onTimeChanged,
    required this.onLanguageChanged,
    required this.onBack,
    required this.onFinish,
  });

  final bool remindersEnabled;
  final NotificationFrequency frequency;
  final Set<int> weekdays;
  final TimeOfDayValue time;
  final LanguageMode language;
  final bool saving;
  final ValueChanged<bool> onRemindersChanged;
  final ValueChanged<NotificationFrequency> onFrequencyChanged;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final ValueChanged<TimeOfDayValue> onTimeChanged;
  final ValueChanged<LanguageMode> onLanguageChanged;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Receive one hadith at a time, at the time that works best for you.',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        SettingsGroup(
          title: 'Reminder',
          children: <Widget>[
            SettingsRow(
              label: 'Remind me',
              trailing: Switch(
                value: remindersEnabled,
                onChanged: onRemindersChanged,
              ),
            ),
            if (remindersEnabled) ...<Widget>[
              SettingsRow(
                label: 'Time',
                value: Formatting.timeOfDay(
                  time.hour,
                  time.minute,
                  use24Hour: use24Hour,
                ),
                onTap: () => _pickTime(context),
              ),
            ],
          ],
        ),
        if (remindersEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Frequency',
            children: <Widget>[
              for (final NotificationFrequency option
                  in <NotificationFrequency>[
                NotificationFrequency.daily,
                NotificationFrequency.selectedDays,
                NotificationFrequency.weekly,
              ])
                ChoiceRow<NotificationFrequency>(
                  label: SettingsLabels.frequencyName(option),
                  value: option,
                  groupValue: frequency,
                  onChanged: onFrequencyChanged,
                ),
            ],
          ),
          if (frequency == NotificationFrequency.selectedDays ||
              frequency == NotificationFrequency.weekly) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _OnboardingWeekdays(
              weekdays: weekdays,
              single: frequency == NotificationFrequency.weekly,
              onChanged: onWeekdaysChanged,
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
        SettingsGroup(
          title: 'Language',
          children: <Widget>[
            for (final LanguageMode mode in LanguageMode.values)
              ChoiceRow<LanguageMode>(
                label: SettingsLabels.language(mode),
                value: mode,
                groupValue: language,
                onChanged: onLanguageChanged,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          onPressed: saving ? null : onFinish,
          child: Text(saving ? 'Setting up…' : 'Start reading'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: saving ? null : onBack, child: const Text('Back')),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: 'Reminder time',
    );
    if (picked == null) return;
    onTimeChanged(TimeOfDayValue(picked.hour, picked.minute));
  }
}

class _OnboardingWeekdays extends StatelessWidget {
  const _OnboardingWeekdays({
    required this.weekdays,
    required this.single,
    required this.onChanged,
  });

  final Set<int> weekdays;
  final bool single;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (int weekday = 1; weekday <= 7; weekday++)
          Semantics(
            selected: weekdays.contains(weekday),
            button: true,
            label: Formatting.fullWeekday(weekday),
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                if (single) {
                  onChanged(<int>{weekday});
                  return;
                }
                final Set<int> next = <int>{...weekdays};
                if (!next.remove(weekday)) next.add(weekday);
                if (next.isEmpty) return;
                onChanged(next);
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTapTarget,
                  minHeight: AppSpacing.minTapTarget,
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: weekdays.contains(weekday)
                      ? colors.accentSoft
                      : colors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: weekdays.contains(weekday)
                        ? colors.accent
                        : colors.border,
                  ),
                ),
                child: Text(
                  Formatting.shortWeekday(weekday),
                  style: AppTypography.metadata.copyWith(
                    color: weekdays.contains(weekday)
                        ? colors.accent
                        : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
