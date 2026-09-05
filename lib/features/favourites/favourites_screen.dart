import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/collection_providers.dart';
import '../../app/favourites_providers.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../app/speech_providers.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/favourite_hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/user_preferences.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/hadith_view.dart';
import '../../shared/widgets/state_views.dart';

/// Saved hadith from every book, newest first.
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FavouriteHadith>> favourites =
        ref.watch(favouritesProvider);

    return AppPage(
      title: 'Favourites',
      child: favourites.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          message: 'Your saved hadith could not be loaded.',
          onRetry: () => ref.invalidate(favouritesProvider),
        ),
        data: (List<FavouriteHadith> value) => value.isEmpty
            ? const _NoFavourites()
            : _FavouritesList(items: value),
      ),
    );
  }
}

class _FavouritesList extends ConsumerWidget {
  const _FavouritesList({required this.items});

  final List<FavouriteHadith> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final String? speakingId = ref.watch(speechControllerProvider);
    final bool canSpeak = ref.watch(speechAvailableProvider).value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          items.length == 1 ? '1 saved hadith' : '${items.length} saved hadith',
          style: AppTypography.metadata.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final FavouriteHadith item in items) ...<Widget>[
          _FavouriteCard(
            item: item,
            languageMode: preferences.languageMode,
            textScale: preferences.textSize.scale,
            isSpeaking: speakingId == item.hadith.id,
            canSpeak: canSpeak,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}

/// One saved hadith, headed by the book it came from and when it was saved.
class _FavouriteCard extends ConsumerWidget {
  const _FavouriteCard({
    required this.item,
    required this.languageMode,
    required this.textScale,
    required this.isSpeaking,
    required this.canSpeak,
  });

  final FavouriteHadith item;
  final LanguageMode languageMode;
  final double textScale;
  final bool isSpeaking;
  final bool canSpeak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final HadithCollection? collection =
        ref.watch(collectionProvider(item.collectionId)).value;

    final List<String> parts = <String>[
      if (collection != null) collection.titleEnglish,
      'Hadith ${item.hadith.hadithNumber}',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            parts.join(' · '),
            style: AppTypography.metadata.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Saved ${Formatting.date(item.savedAt)}',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          HadithView(
            hadith: item.hadith,
            languageMode: languageMode,
            textScale: textScale,
            // The citation is already in the card heading.
            showReference: false,
            onSpeakEnglish: canSpeak
                ? () => ref
                    .read(speechControllerProvider.notifier)
                    .toggle(item.hadith.id, item.hadith.englishText ?? '')
                : null,
            isSpeaking: isSpeaking,
            // Always true here: every card on this screen is a favourite, so
            // the heart is the way to remove it.
            isFavourite: true,
            onToggleFavourite: () => ref
                .read(favouritesControllerProvider.notifier)
                .toggle(item.hadith),
          ),
        ],
      ),
    );
  }
}

class _NoFavourites extends StatelessWidget {
  const _NoFavourites();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.favorite_border,
      title: 'No favourites yet',
      message: 'Tap the heart beside any hadith to keep it here, from any book.',
      action: FilledButton(
        onPressed: () => context.go(Routes.today),
        child: const Text('Back to today’s hadith'),
      ),
    );
  }
}
