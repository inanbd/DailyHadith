import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Visual weight of a [NoticeBanner].
enum NoticeTone {
  /// Neutral information, e.g. reminders being off.
  info,

  /// Something the reader should not overlook, e.g. placeholder content.
  warning,
}

/// A single-line-ish inline notice.
///
/// Used sparingly: development-fixture content and reminders blocked by the
/// operating system are the only two things that earn one.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    this.title,
    this.tone = NoticeTone.info,
    this.action,
    super.key,
  });

  final String? title;
  final String message;
  final NoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isWarning = tone == NoticeTone.warning;
    final Color accent = isWarning ? colors.warm : colors.accent;

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isWarning ? colors.surfaceMuted : colors.accentSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppSpacing.md,
                top: 2,
              ),
              child: Icon(
                isWarning ? Icons.info_outline : Icons.notifications_none,
                size: 18,
                color: accent,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null) ...<Widget>[
                    Text(
                      title!,
                      style: AppTypography.metadata.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    message,
                    style: AppTypography.reference.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
