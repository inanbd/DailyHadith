import 'package:flutter/material.dart';

import '../../core/utils/formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "24 of 1,896 read" above a thin progress track.
class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({
    required this.read,
    required this.total,
    this.label,
    this.showPercentage = false,
    super.key,
  });

  final int read;
  final int total;

  /// Overrides the default "N of M read" caption.
  final String? label;

  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double fraction =
        total <= 0 ? 0 : (read / total).clamp(0.0, 1.0).toDouble();
    final String caption = label ??
        '${Formatting.count(read)} of ${Formatting.count(total)} read';

    return Semantics(
      // One spoken label instead of three disconnected fragments.
      label: showPercentage
          ? '$caption, ${Formatting.percent(fraction * 100)} complete'
          : caption,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                caption,
                style: AppTypography.progressMeta.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (showPercentage)
                Text(
                  Formatting.percent(fraction * 100),
                  style: AppTypography.progressMeta.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              // A quiet fill rather than a jump when progress changes.
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: fraction),
              builder: (BuildContext context, double value, Widget? child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: colors.accentSoft,
                  color: colors.accent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
