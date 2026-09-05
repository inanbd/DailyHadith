import 'package:flutter/material.dart';

import '../../app/collection_providers.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/reading_progress.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'progress_bar.dart';

/// A collection as it appears in the library: title, Arabic title, compiler,
/// size, and progress once started.
class BookCard extends StatelessWidget {
  const BookCard({
    required this.entry,
    required this.onTap,
    this.isCurrent = false,
    this.action,
    super.key,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;

  /// Marks the book the Today screen is currently reading from.
  final bool isCurrent;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final HadithCollection collection = entry.collection;
    final ReadingProgress progress = entry.progress;
    final bool started = entry.hasStarted;

    return Semantics(
      button: true,
      label: _semanticLabel(collection, progress, started),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isCurrent ? colors.accent : colors.border,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      collection.titleEnglish,
                      style: AppTypography.sectionTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCurrent) const _CurrentBadge(),
                ],
              ),
              if (collection.titleArabic.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    collection.titleArabic,
                    locale: const Locale('ar'),
                    style: AppTypography.arabicTitle.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                _subtitle(collection),
                style: AppTypography.metadata.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (collection.isFixture) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _Tag(label: 'Development data', color: colors.warm),
              ] else if (!collection.isReadable) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _Tag(label: 'Dataset not installed', color: colors.textSecondary),
              ],
              if (started) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                ReadingProgressBar(
                  read: progress.totalRead,
                  total: progress.totalHadith,
                  label: '${Formatting.count(progress.totalRead)} read',
                  showPercentage: true,
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(HadithCollection collection) {
    final List<String> parts = <String>[
      if (collection.compiler.isNotEmpty) collection.compiler,
      '${Formatting.count(collection.totalHadith)} hadith',
    ];
    return parts.join(' · ');
  }

  static String _semanticLabel(
    HadithCollection collection,
    ReadingProgress progress,
    bool started,
  ) {
    final StringBuffer buffer = StringBuffer(collection.titleEnglish);
    if (collection.compiler.isNotEmpty) buffer.write(', ${collection.compiler}');
    buffer.write(', ${Formatting.count(collection.totalHadith)} hadith');
    if (started) {
      buffer.write(
        ', ${Formatting.count(progress.totalRead)} read, '
        '${Formatting.percent(progress.percentage)} complete',
      );
    }
    if (collection.isFixture) buffer.write(', development data');
    if (!collection.isReadable) buffer.write(', dataset not installed');
    return buffer.toString();
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Current',
        style: AppTypography.progressMeta.copyWith(color: colors.accent),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.progressMeta.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
