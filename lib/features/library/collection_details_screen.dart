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
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/state_views.dart';

/// One collection in full: description, size, attribution and progress, with a
/// single clear call to action.
class CollectionDetailsScreen extends ConsumerWidget {
  const CollectionDetailsScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HadithCollection?> collection =
        ref.watch(collectionProvider(collectionId));

    return AppPage(
      title: collection.value?.titleEnglish ?? 'Collection',
      showBackButton: true,
      child: collection.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          message: 'This collection could not be loaded.',
          onRetry: () => ref.invalidate(collectionsProvider),
        ),
        data: (HadithCollection? value) {
          if (value == null) {
            return const ErrorStateView(
              title: 'Collection not found',
              message: 'This collection is no longer in the library.',
            );
          }
          return _Details(collection: value);
        },
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.collection});

  final HadithCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<ReadingProgress> progress =
        ref.watch(collectionProgressProvider(collection.id));
    final String? currentId = ref.watch(
      userPreferencesProvider
          .select((UserPreferences prefs) => prefs.currentCollectionId),
    );
    final bool isCurrent = currentId == collection.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (collection.titleArabic.isNotEmpty)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              collection.titleArabic,
              locale: const Locale('ar'),
              style: AppTypography.arabicTitle.copyWith(
                fontSize: 22,
                color: colors.textPrimary,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${collection.compiler} · '
          '${Formatting.count(collection.totalHadith)} hadith',
          style: AppTypography.metadata.copyWith(color: colors.textSecondary),
        ),
        if (collection.isFixture) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const NoticeBanner(
            tone: NoticeTone.warning,
            title: 'Development data',
            message:
                'The text in this collection is placeholder content for '
                'building and testing. It is not hadith.',
          ),
        ] else if (!collection.isReadable) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const NoticeBanner(
            title: 'Dataset not installed',
            message:
                'The app knows about this collection but has no text for it '
                'yet. See DATA_SOURCES.md for how to import a verified '
                'dataset.',
          ),
        ],
        if (collection.description.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            collection.description,
            style: AppTypography.body.copyWith(
              color: colors.textPrimary,
              height: 1.7,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        progress.when(
          loading: () => const SizedBox.shrink(),
          error: (Object error, StackTrace stack) => const SizedBox.shrink(),
          data: (ReadingProgress value) {
            if (!value.hasStarted && value.totalRead == 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: ReadingProgressBar(
                read: value.totalRead,
                total: value.totalHadith,
                showPercentage: true,
              ),
            );
          },
        ),
        if (collection.isReadable)
          FilledButton(
            onPressed: () => _startReading(context, ref),
            child: Text(_ctaLabel(progress.value, isCurrent)),
          ),
        const SizedBox(height: AppSpacing.xxl),
        _SourceAttribution(collection: collection),
      ],
    );
  }

  static String _ctaLabel(ReadingProgress? progress, bool isCurrent) {
    final bool started = (progress?.totalRead ?? 0) > 0;
    if (isCurrent && started) return 'Continue reading';
    if (started) return 'Continue reading';
    return 'Start reading';
  }

  /// Makes this the current book and opens Today on it.
  ///
  /// The previous book's progress is untouched — switching back later resumes
  /// exactly where it left off.
  Future<void> _startReading(BuildContext context, WidgetRef ref) async {
    await ref
        .read(userPreferencesProvider.notifier)
        .setCurrentCollection(collection.id);
    // Reminders name the current book, so they are re-armed with the new title.
    await ref.read(notificationPreferencesProvider.notifier).applyToScheduler();
    await ref.read(todayControllerProvider.notifier).refresh();
    if (context.mounted) context.go(Routes.today);
  }
}

/// Where this collection's text came from. Always reachable, never hidden.
class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.collection});

  final HadithCollection collection;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final ContentSource source = collection.source;
    final TextStyle style =
        AppTypography.reference.copyWith(color: colors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Divider(color: colors.border, height: 1),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'SOURCE',
          style: AppTypography.overline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(source.name, style: style),
        if (source.translator != null)
          Text('Translation: ${source.translator}', style: style),
        if (source.licence != null) Text('Licence: ${source.licence}', style: style),
        if (source.url != null) Text(source.url!, style: style),
        if (source.retrievedAt != null)
          Text('Retrieved ${Formatting.date(source.retrievedAt!)}', style: style),
      ],
    );
  }
}
