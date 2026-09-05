import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A calm, non-judgemental empty state.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.message,
    this.title,
    this.icon,
    this.action,
    super.key,
  });

  final String? title;
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 28, color: colors.textSecondary),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: AppTypography.sectionTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            message,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            Align(alignment: AlignmentDirectional.centerStart, child: action),
          ],
        ],
      ),
    );
  }
}

/// Renders a failure with a retry affordance.
///
/// Copy stays plain: the reader is told what is not working and what they can
/// do, never given a stack trace.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.message,
    this.title = 'Something went wrong',
    this.detail,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String title;
  final String message;

  /// Optional secondary line, e.g. instructions for installing a dataset.
  final String? detail;

  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.sectionTitle.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              detail!,
              style: AppTypography.reference.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ],
      ),
    );
  }
}

/// A quiet loading state — no spinner-heavy chrome, just a thin indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              backgroundColor: colors.accentSoft,
              color: colors.accent,
              minHeight: 2,
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              label!,
              style: AppTypography.metadata.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
