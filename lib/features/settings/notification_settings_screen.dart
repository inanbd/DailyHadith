import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_scheduler.dart';
import '../../domain/services/reminder_schedule.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/settings_group.dart';
import 'reminder_permission_flow.dart';
import 'settings_labels.dart';

/// Reminder frequency, days and time — plus an honest account of whether the
/// operating system is actually letting reminders through, and a way to fix it
/// when it is not.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationPreferences preferences =
        ref.watch(notificationPreferencesProvider);
    final AsyncValue<ReminderReadiness> readinessAsync =
        ref.watch(reminderReadinessProvider);
    // Until the platform has answered, the OS is given the benefit of the
    // doubt: nothing is reported as blocked or missing on the strength of a
    // question that has not come back yet.
    final ReminderReadiness readiness =
        readinessAsync.value ?? ReminderReadiness.unknown;
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    return AppPage(
      title: 'Notifications',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (preferences.enabled && readiness.isBlocked) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.warning,
              title: 'Reminders are blocked',
              message:
                  'Notifications are turned off for Daily Hadith in your device '
                  'settings, so nothing can reach you. Your reading and '
                  'progress still work as normal.',
              action: const _OpenDeviceSettingsButton(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          SettingsGroup(
            title: 'Reminders',
            children: <Widget>[
              SettingsRow(
                label: 'Daily reminder',
                description: preferences.enabled
                    ? 'A gentle prompt when your next hadith is ready.'
                    : 'Turn on reminders whenever you’d like a gentle prompt '
                        'to read your next hadith.',
                trailing: Switch(
                  value: preferences.enabled,
                  onChanged: (bool value) => _setEnabled(context, ref, value),
                ),
              ),
            ],
          ),
          if (preferences.enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(
              title: 'Frequency',
              children: <Widget>[
                for (final NotificationFrequency frequency
                    in NotificationFrequency.values)
                  ChoiceRow<NotificationFrequency>(
                    label: SettingsLabels.frequencyName(frequency),
                    value: frequency,
                    groupValue: preferences.frequency,
                    onChanged: (NotificationFrequency value) => _update(
                      ref,
                      preferences.copyWith(
                        frequency: value,
                        // Anchor "every other day" to today so the cadence is
                        // stable from the moment it is chosen.
                        anchorDate: value == NotificationFrequency.everyOtherDay
                            ? DateTime.now()
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (preferences.frequency == NotificationFrequency.selectedDays ||
                preferences.frequency == NotificationFrequency.weekly) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              _WeekdayPicker(
                preferences: preferences,
                onChanged: (Set<int> days) => _update(
                  ref,
                  preferences.copyWith(selectedWeekdays: days),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(
              title: 'Time',
              children: <Widget>[
                SettingsRow(
                  label: 'Reminder time',
                  value: Formatting.timeOfDay(
                    preferences.time.hour,
                    preferences.time.minute,
                    use24Hour: use24Hour,
                  ),
                  onTap: () => _pickTime(context, ref, preferences),
                ),
              ],
            ),
            if (readinessAsync.hasValue && !readiness.isBlocked) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              _DeliveryGroup(readiness: readiness),
            ],
            const SizedBox(height: AppSpacing.xl),
            _UpcomingReminders(preferences: preferences),
          ],
        ],
      ),
    );
  }

  /// Turning reminders on is the moment the OS prompts make sense: the reader
  /// has already said what they want.
  static Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final NotificationPreferences preferences =
        ref.read(notificationPreferencesProvider);

    // Permissions first, so the reminders armed below can be armed as exact
    // alarms rather than approximate ones.
    if (enabled) await ReminderPermissionFlow.run(context);

    await _update(ref, preferences.copyWith(enabled: enabled));
  }

  static Future<void> _update(
    WidgetRef ref,
    NotificationPreferences next,
  ) async {
    // Persisting and rescheduling happen together, so pending reminders are
    // always cancelled and re-armed to match what is on screen.
    await ref.read(notificationPreferencesProvider.notifier).update(next);
  }

  static Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences preferences,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.time.hour,
        minute: preferences.time.minute,
      ),
      helpText: 'Reminder time',
    );
    if (picked == null) return;
    await _update(
      ref,
      preferences.copyWith(
        time: TimeOfDayValue(picked.hour, picked.minute),
      ),
    );
  }
}

/// Takes the reader to the system screen where notifications can be switched
/// back on.
///
/// Not every platform lets an app open that screen. When it cannot, the reader
/// is told where to go rather than left with a button that does nothing.
class _OpenDeviceSettingsButton extends ConsumerWidget {
  const _OpenDeviceSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        final bool opened =
            await ReminderPermissionFlow.openSystemSettings(context);
        if (opened || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turn Daily Hadith back on under Notifications in your '
              'device settings.',
            ),
          ),
        );
      },
      child: const Text('Open device settings'),
    );
  }
}

/// The permissions that decide whether a reminder arrives *on time*, and every
/// day, rather than whether it arrives at all.
///
/// Shown as plain status rows the reader can act on, because these are the two
/// things that make a correctly scheduled reminder turn up hours late or stop
/// turning up at all — and neither is discoverable from the OS side.
class _DeliveryGroup extends StatelessWidget {
  const _DeliveryGroup({required this.readiness});

  final ReminderReadiness readiness;

  /// Requirements this platform actually has. iOS delivers reminders itself,
  /// so on it there is nothing here worth showing.
  static const List<ReminderRequirement> _requirements = <ReminderRequirement>[
    ReminderRequirement.exactTiming,
    ReminderRequirement.background,
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<ReminderRequirement> shown = <ReminderRequirement>[
      for (final ReminderRequirement requirement in _requirements)
        if (readiness.statusOf(requirement) !=
            NotificationPermissionStatus.unsupported)
          requirement,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsGroup(
          title: 'Delivery',
          children: <Widget>[
            for (final ReminderRequirement requirement in shown)
              _RequirementRow(
                requirement: requirement,
                status: readiness.statusOf(requirement),
              ),
          ],
        ),
        if (readiness.isUnreliable) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Some phones also have their own battery manager — often under '
            'Battery or App management — that puts apps to sleep. Allowing '
            'Daily Hadith to run in the background there keeps reminders '
            'arriving every day.',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _RequirementRow extends ConsumerStatefulWidget {
  const _RequirementRow({required this.requirement, required this.status});

  final ReminderRequirement requirement;
  final NotificationPermissionStatus status;

  @override
  ConsumerState<_RequirementRow> createState() => _RequirementRowState();
}

class _RequirementRowState extends ConsumerState<_RequirementRow> {
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    final bool granted =
        widget.status == NotificationPermissionStatus.granted;
    return SettingsRow(
      label: ReminderRequirementLabels.name(widget.requirement),
      description: ReminderRequirementLabels.reason(widget.requirement),
      value: ReminderRequirementLabels.status(widget.status),
      // Granted needs no action, and re-asking would only bounce the reader
      // out to a settings screen for no reason.
      onTap: granted || _asking ? null : _request,
    );
  }

  Future<void> _request() async {
    setState(() => _asking = true);
    try {
      await ReminderPermissionFlow.requestOne(context, widget.requirement);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.preferences, required this.onChanged});

  final NotificationPreferences preferences;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool single =
        preferences.frequency == NotificationFrequency.weekly;
    final Set<int> selected = preferences.selectedWeekdays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            single ? 'DAY' : 'DAYS',
            style: AppTypography.overline.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int weekday = 1; weekday <= 7; weekday++)
              _WeekdayChip(
                weekday: weekday,
                selected: selected.contains(weekday),
                onTap: () {
                  if (single) {
                    onChanged(<int>{weekday});
                    return;
                  }
                  final Set<int> next = <int>{...selected};
                  if (!next.remove(weekday)) next.add(weekday);
                  // Never leave the schedule with nothing to fire on.
                  if (next.isEmpty) return;
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: Formatting.fullWeekday(weekday),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTapTarget,
            minHeight: AppSpacing.minTapTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Text(
            Formatting.shortWeekday(weekday),
            style: AppTypography.metadata.copyWith(
              color: selected ? colors.accent : colors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The next few reminders, computed from the settings on screen. Reassures the
/// reader that a change took effect without making them wait a day to find out.
class _UpcomingReminders extends StatelessWidget {
  const _UpcomingReminders({required this.preferences});

  final NotificationPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final List<DateTime> upcoming = ReminderSchedule(preferences)
        .nextOccurrences(DateTime.now(), count: 3);

    if (upcoming.isEmpty) {
      return Text(
        'These settings will not produce any reminders.',
        style: AppTypography.reference.copyWith(color: colors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'NEXT REMINDERS',
          style: AppTypography.overline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final DateTime moment in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${Formatting.date(moment)} · '
              '${Formatting.timeOfDay(moment.hour, moment.minute, use24Hour: use24Hour)}',
              style: AppTypography.reference.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Reminders follow your device’s time zone.',
          style: AppTypography.reference.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
