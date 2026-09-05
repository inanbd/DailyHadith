import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/user_preferences.dart';
import '../../features/today/today_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/state_views.dart';

/// Reading progress per collection. Deliberately not a streak dashboard.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LibraryEntry>> started =
        ref.watch(startedCollectionsProvider);

    return AppPage(
      title: 'Your Progress',
      child: started.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          message: 'Your progress could not be loaded.',
          onRetry: () => ref.invalidate(libraryProvider),
        ),
        data: (List<LibraryEntry> entries) {
          if (entries.isEmpty) {
            return EmptyStateView(
              icon: Icons.donut_large_outlined,
              message:
                  'Your reading progress will appear here once you start a '
                  'collection.',
              action: FilledButton(
                onPressed: () => context.go(Routes.library),
                child: const Text('Open the library'),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final LibraryEntry entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ProgressCard(entry: entry),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final HadithCollection collection = entry.collection;
    final ReadingProgress progress = entry.progress;
    final bool isCurrent = ref.watch(
          userPreferencesProvider
              .select((UserPreferences prefs) => prefs.currentCollectionId),
        ) ==
        collection.id;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            collection.titleEnglish,
            style: AppTypography.sectionTitle.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${Formatting.count(progress.totalRead)} of '
            '${Formatting.count(progress.totalHadith)} hadith',
            style: AppTypography.metadata.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ReadingProgressBar(
            read: progress.totalRead,
            total: progress.totalHadith,
            label: Formatting.percent(progress.percentage),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProgressDetails(progress: progress),
          const SizedBox(height: AppSpacing.lg),
          if (progress.isComplete)
            OutlinedButton(
              onPressed: () => context.go(Routes.collection(collection.id)),
              child: const Text('Completed'),
            )
          else
            FilledButton(
              onPressed: () => _continueReading(context, ref, isCurrent),
              child: const Text('Continue reading'),
            ),
        ],
      ),
    );
  }

  Future<void> _continueReading(
    BuildContext context,
    WidgetRef ref,
    bool isCurrent,
  ) async {
    if (!isCurrent) {
      await ref
          .read(userPreferencesProvider.notifier)
          .setCurrentCollection(entry.collection.id);
      await ref
          .read(notificationPreferencesProvider.notifier)
          .applyToScheduler();
    }
    await ref.read(todayControllerProvider.notifier).refresh();
    if (context.mounted) context.go(Routes.today);
  }
}

/// Started date, pace and estimated completion — each shown only when it can
/// be stated meaningfully.
class _ProgressDetails extends StatelessWidget {
  const _ProgressDetails({required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle style = AppTypography.reference.copyWith(
      color: colors.textSecondary,
    );

    final List<String> lines = <String>[
      if (progress.startedAt != null)
        'Started ${Formatting.date(progress.startedAt!)}',
      if (progress.pacePerDay != null)
        'Reading pace: ${_pace(progress.pacePerDay!)}',
      if (progress.estimatedCompletion != null)
        'Estimated completion: '
            '${Formatting.date(progress.estimatedCompletion!)}',
      if (progress.completedAt != null)
        'Completed ${Formatting.date(progress.completedAt!)}',
    ];

    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(line, style: style),
          ),
      ],
    );
  }

  static String _pace(double perDay) {
    if (perDay >= 1) {
      final String value = perDay == perDay.roundToDouble()
          ? perDay.round().toString()
          : perDay.toStringAsFixed(1);
      return '$value hadith/day';
    }
    final double perWeek = perDay * 7;
    return '${perWeek.toStringAsFixed(1)} hadith/week';
  }
}
