import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/repositories/notification_scheduler.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import 'settings_labels.dart';

/// Asks the operating system for everything a reminder depends on, in the
/// order that makes sense to the reader.
///
/// Every prompt here is raised only once the reader has asked for reminders,
/// so none of them arrives without a reason they already agreed to. And none
/// of them can stop reminders being switched on: declining leaves the reader
/// with a less punctual reminder, not a broken app, and the notification
/// settings screen keeps offering the fix afterwards.
/// Every prompt here suspends the caller while a system dialog or a whole
/// system screen sits on top of the app, which can take as long as the reader
/// takes. Providers are therefore reached through the [ProviderContainer],
/// captured before the first await, rather than through the calling widget's
/// `ref`: the widget may well be gone by the time the reader answers, and a
/// half-finished permission flow must not take the rest of the caller's work
/// down with it.
abstract final class ReminderPermissionFlow {
  /// Raises every outstanding prompt and reports what the OS ended up allowing.
  ///
  /// Permission to arrive at all comes first, from the OS's own dialog. Only
  /// if that succeeds is the reader asked about punctuality — those two send
  /// them out to system screens, so they are explained first and asked for
  /// together.
  static Future<ReminderReadiness> run(BuildContext context) async {
    final ProviderContainer container = _containerOf(context);
    final NotificationScheduler scheduler =
        container.read(notificationSchedulerProvider);
    ReminderReadiness readiness = await scheduler.readiness();

    if (readiness.needs(ReminderRequirement.notifications)) {
      // For a reader who has refused before, the OS returns from this without
      // showing anything. That is picked up below as "still blocked", and the
      // settings screen offers the way into system settings rather than this
      // flow nagging on the spot.
      await scheduler.request(ReminderRequirement.notifications);
      readiness = await scheduler.readiness();
    }

    // While nothing can arrive at all, nothing else is worth asking about.
    if (readiness.notifications != NotificationPermissionStatus.granted) {
      container.invalidate(reminderReadinessProvider);
      return readiness;
    }

    final List<ReminderRequirement> punctuality = readiness.outstanding;
    if (punctuality.isNotEmpty && context.mounted) {
      final bool proceed = await _explain(context, punctuality);
      if (proceed) {
        for (final ReminderRequirement requirement in punctuality) {
          await scheduler.request(requirement);
        }
        readiness = await scheduler.readiness();
      }
    }

    container.invalidate(reminderReadinessProvider);
    return readiness;
  }

  /// The scope's container, which outlives any widget that starts a prompt.
  static ProviderContainer _containerOf(BuildContext context) =>
      ProviderScope.containerOf(context, listen: false);

  /// Raises one prompt on its own, for the reader who comes back to fix a
  /// single row later.
  ///
  /// Nothing is re-armed here. Being allowed exact alarms only changes anything
  /// once the reminders are scheduled again, and the app root does that
  /// whenever what the OS allows actually changes — wherever the change came
  /// from, this prompt or system settings while the app was in the background.
  static Future<void> requestOne(
    BuildContext context,
    ReminderRequirement requirement,
  ) async {
    final ProviderContainer container = _containerOf(context);
    await container.read(notificationSchedulerProvider).request(requirement);
    container.invalidate(reminderReadinessProvider);
  }

  /// Opens system settings, for a permission the OS will no longer prompt for.
  ///
  /// Readiness is re-read when the app returns to the foreground, so whatever
  /// the reader changes there is picked up without them coming back here.
  static Future<bool> openSystemSettings(BuildContext context) =>
      _containerOf(context)
          .read(notificationSchedulerProvider)
          .openSystemNotificationSettings();

  /// Explains what the next system screens are for, before jumping to them.
  ///
  /// Android hands the reader a bare settings page with no context of its own,
  /// so the context has to come from here.
  static Future<bool> _explain(
    BuildContext context,
    List<ReminderRequirement> requirements,
  ) async {
    final AppColors colors = context.colors;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          requirements.length == 1
              ? 'One more permission'
              : 'Two more permissions',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              requirements.length == 1
                  ? 'Your phone needs one more permission before a reminder '
                      'can be relied on:'
                  : 'Your phone needs two more permissions before a reminder '
                      'can be relied on:',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final ReminderRequirement requirement in requirements)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ReminderRequirementLabels.name(requirement),
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ReminderRequirementLabels.reason(requirement),
                      style: AppTypography.reference.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'You’ll be taken to your phone’s settings for each one.',
              style: AppTypography.reference.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }
}
