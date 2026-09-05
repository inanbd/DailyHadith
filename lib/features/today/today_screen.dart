import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/user_preferences.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/hadith_view.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/state_views.dart';
import 'today_controller.dart';

/// The default screen: today's hadith, and almost nothing else.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayState> state = ref.watch(todayControllerProvider);

    return AppPage(
      title: 'Today’s Hadith',
      child: state.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => _TodayError(error: error),
        data: (TodayState value) => _TodayBody(state: value),
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HadithCollection? collection = state.collection;
    if (collection == null) return const _NoCollectionChosen();

    if (state.isCollectionComplete) {
      return BookCompletionView(
        collection: collection,
        progress: state.progress!,
        onReadAgain: () =>
            ref.read(todayControllerProvider.notifier).restartCollection(),
        onChooseAnother: () => context.go(Routes.library),
      );
    }

    final Hadith? hadith = state.hadith;
    if (hadith == null) {
      return ErrorStateView(
        title: 'This hadith could not be loaded',
        message:
            'The text for position ${state.ordinal} is missing from local '
            'storage. Reinstalling the collection usually fixes this.',
        onRetry: () => ref.read(todayControllerProvider.notifier).refresh(),
      );
    }

    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final ReadingProgress progress = state.progress!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HadithMeta(collection: collection, hadith: hadith),
        if (collection.isFixture) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const NoticeBanner(
            tone: NoticeTone.warning,
            title: 'Development data',
            message:
                'This is placeholder text for building and testing the app — '
                'not hadith. Import a verified collection to read real content.',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        // A gentle cross-fade when the hadith changes, keyed so the animation
        // runs on content change rather than on every rebuild.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: HadithView(
            key: ValueKey<String>(hadith.id),
            hadith: hadith,
            languageMode: preferences.languageMode,
            textScale: preferences.textSize.scale,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ReadingProgressBar(
          read: progress.totalRead,
          total: progress.totalHadith,
        ),
        const SizedBox(height: AppSpacing.xl),
        _ReadingActions(state: state),
      ],
    );
  }
}

/// "Riyad as-Salihin · Hadith 24" and, when the source provides it, the book
/// number and chapter.
class _HadithMeta extends StatelessWidget {
  const _HadithMeta({required this.collection, required this.hadith});

  final HadithCollection collection;
  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<String> parts = <String>[
      if (hadith.bookNumber != null) 'Book ${hadith.bookNumber}',
      'Hadith ${hadith.hadithNumber}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          collection.titleEnglish,
          style: AppTypography.metadata.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          parts.join(' · '),
          style: AppTypography.metadata.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Previous · Mark as read · Next.
class _ReadingActions extends ConsumerWidget {
  const _ReadingActions({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TodayController controller =
        ref.read(todayControllerProvider.notifier);
    final AppColors colors = context.colors;

    return Row(
      children: <Widget>[
        _NavButton(
          icon: Icons.chevron_left,
          tooltip: 'Previous hadith',
          onPressed: state.hasPrevious ? controller.goToPrevious : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: state.isRead
              ? OutlinedButton.icon(
                  onPressed: controller.markUnread,
                  icon: Icon(Icons.check, size: 18, color: colors.accent),
                  label: const Text('Read'),
                )
              : FilledButton(
                  onPressed: controller.markRead,
                  child: const Text('Mark as read'),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        _NavButton(
          icon: Icons.chevron_right,
          tooltip: 'Next hadith',
          onPressed: state.hasNext ? controller.goToNext : null,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return SizedBox(
      width: AppSpacing.minTapTarget,
      height: AppSpacing.minTapTarget,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSpacing.minTapTarget),
          side: BorderSide(color: colors.border),
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(
            icon,
            size: 22,
            color: onPressed == null ? colors.border : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NoCollectionChosen extends StatelessWidget {
  const _NoCollectionChosen();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) => EmptyStateView(
        icon: Icons.menu_book_outlined,
        title: 'No collection chosen yet',
        message: 'Choose a collection to begin reading.',
        action: FilledButton(
          onPressed: () => context.go(Routes.library),
          child: const Text('Open the library'),
        ),
      ),
    );
  }
}

class _TodayError extends ConsumerWidget {
  const _TodayError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => ref.read(todayControllerProvider.notifier).refresh();

    if (error is DatasetUnavailableException) {
      return ErrorStateView(
        title: 'This collection has no text yet',
        message:
            'The hadith data for this collection has not been added to the '
            'app. Nothing is missing from your reading progress — choose '
            'another collection, or import this one.',
        detail: 'See DATA_SOURCES.md for how to import a verified dataset.',
        onRetry: retry,
      );
    }

    if (error is CatalogUnavailableException) {
      return ErrorStateView(
        title: 'The library could not be loaded',
        message:
            'The list of collections is missing or unreadable. Reinstalling '
            'the app restores it.',
        onRetry: retry,
      );
    }

    return ErrorStateView(
      message:
          'Today’s hadith could not be opened. Your reading progress is safe.',
      onRetry: retry,
    );
  }
}

/// The restrained completion state shown once a book is finished.
class BookCompletionView extends StatelessWidget {
  const BookCompletionView({
    required this.collection,
    required this.progress,
    required this.onReadAgain,
    required this.onChooseAnother,
    super.key,
  });

  final HadithCollection collection;
  final ReadingProgress progress;
  final VoidCallback onReadAgain;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Alhamdulillah',
          style: AppTypography.pageTitle.copyWith(color: colors.accent),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You completed ${collection.titleEnglish}.',
          style: AppTypography.englishBody.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${Formatting.count(progress.totalRead)} hadith read.',
          style: AppTypography.metadata.copyWith(color: colors.textSecondary),
        ),
        if (progress.startedAt != null && progress.completedAt != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${Formatting.date(progress.startedAt!)} — '
            '${Formatting.date(progress.completedAt!)}',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        const HadithDivider(),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          onPressed: onChooseAnother,
          child: const Text('Choose another book'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onReadAgain,
          child: const Text('Read again from the beginning'),
        ),
      ],
    );
  }
}
