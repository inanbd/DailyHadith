import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A labelled group of settings rows inside a single bordered surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: AppTypography.overline.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.lg),
                    child: Divider(height: 1, color: colors.border),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A tappable settings row: label on the left, current value and chevron on
/// the right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    this.value,
    this.description,
    this.onTap,
    this.trailing,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? value;
  final String? description;
  final VoidCallback? onTap;

  /// Replaces the value + chevron, e.g. with a switch.
  final Widget? trailing;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color labelColor =
        enabled ? colors.textPrimary : colors.textSecondary;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.body.copyWith(color: labelColor),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: AppTypography.reference.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else ...<Widget>[
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );

    if (onTap == null || !enabled) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: content,
      );
    }

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: content,
        ),
      ),
    );
  }
}

/// A radio-style choice row used by the language, appearance and frequency
/// screens.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool selected = value == groupValue;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onChanged(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (description != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: AppTypography.reference.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: selected ? colors.accent : colors.border,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
