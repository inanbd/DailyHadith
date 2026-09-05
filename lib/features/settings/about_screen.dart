import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/collection_providers.dart';
import '../../core/utils/formatting.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/notice_banner.dart';
import '../../shared/widgets/state_views.dart';

/// Attribution for every collection, plus a plain statement of what the app
/// does and does not do with data.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final AsyncValue<List<HadithCollection>> collections =
        ref.watch(browsableCollectionsProvider);

    return AppPage(
      title: 'Hadith sources',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hadith text in this app is reproduced from the sources listed '
            'below. Nothing is generated, paraphrased or rewritten by the '
            'app.',
            style: AppTypography.body.copyWith(
              color: colors.textPrimary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          collections.when(
            loading: () => const LoadingView(),
            error: (Object error, StackTrace stack) => const ErrorStateView(
              message: 'Source information could not be loaded.',
            ),
            data: (List<HadithCollection> value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final HadithCollection collection in value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _SourceCard(collection: collection),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'PRIVACY',
            style: AppTypography.overline.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No account is required and nothing you read leaves your device. '
            'The app asks for one permission — notifications — and only once '
            'you have chosen a reminder time.',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'TYPEFACES',
            style: AppTypography.overline.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Inter and Noto Naskh Arabic, both used under the SIL Open Font '
            'License 1.1.',
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.collection});

  final HadithCollection collection;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final ContentSource source = collection.source;
    final TextStyle style = AppTypography.reference.copyWith(
      color: colors.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            collection.titleEnglish,
            style: AppTypography.metadata.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(source.name, style: style),
          if (source.translator != null)
            Text('Translation: ${source.translator}', style: style),
          if (source.licence != null)
            Text('Licence: ${source.licence}', style: style),
          if (source.url != null) Text(source.url!, style: style),
          if (source.retrievedAt != null)
            Text(
              'Retrieved ${Formatting.date(source.retrievedAt!)}',
              style: style,
            ),
          if (collection.isFixture) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const NoticeBanner(
              tone: NoticeTone.warning,
              message:
                  'Placeholder text for development. Not hadith content.',
            ),
          ],
        ],
      ),
    );
  }
}
