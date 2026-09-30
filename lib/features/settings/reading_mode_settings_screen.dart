import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/entities/user_preferences.dart';
import '../../features/today/today_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/settings_group.dart';
import '../../shared/widgets/state_views.dart';
import 'settings_labels.dart';

/// How each day's hadith is chosen: the next one in the current book, or one
/// at random from books the reader picks.
class ReadingModeSettingsScreen extends ConsumerWidget {
  const ReadingModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserPreferences preferences = ref.watch(userPreferencesProvider);
    final AsyncValue<HadithCollection?> current =
        ref.watch(currentCollectionProvider);
    final AppColors colors = context.colors;
    final String currentTitle = current.value?.titleEnglish ?? 'your book';

    return AppPage(
      title: 'Daily hadith',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SettingsGroup(
            title: 'How hadith are chosen',
            children: <Widget>[
              ChoiceRow<ReadingOrder>(
                label: SettingsLabels.readingOrder(ReadingOrder.sequential),
                description:
                    'Read $currentTitle from beginning to end, one hadith at '
                    'a time.',
                value: ReadingOrder.sequential,
                groupValue: preferences.readingOrder,
                onChanged: (ReadingOrder value) => _setOrder(ref, value),
              ),
              ChoiceRow<ReadingOrder>(
                label: SettingsLabels.readingOrder(ReadingOrder.random),
                description:
                    'A hadith chosen at random from the books you pick. It '
                    'stays the same until your next reminder.',
                value: ReadingOrder.random,
                groupValue: preferences.readingOrder,
                onChanged: (ReadingOrder value) => _setOrder(ref, value),
              ),
            ],
          ),
          if (preferences.isRandom) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            const _RandomBooksGroup(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Hadith you have already read are skipped until you have read '
              'every hadith in these books. Reading at random never moves your '
              'place in a book you are reading in order.',
              style: AppTypography.reference.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _setOrder(WidgetRef ref, ReadingOrder order) async {
    await ref.read(userPreferencesProvider.notifier).setReadingOrder(order);
    await ref.read(todayControllerProvider.notifier).refresh();
  }
}

/// One row per readable book, each switched in or out of random mode's pool.
class _RandomBooksGroup extends ConsumerWidget {
  const _RandomBooksGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HadithCollection>> collections =
        ref.watch(browsableCollectionsProvider);
    final List<String> pool = ref.watch(
      userPreferencesProvider.select((UserPreferences p) => p.randomPool),
    );

    return collections.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => ErrorStateView(
        message: 'The list of books could not be loaded.',
        onRetry: () => ref.invalidate(collectionsProvider),
      ),
      data: (List<HadithCollection> all) {
        final List<HadithCollection> readable =
            all.where((HadithCollection c) => c.isReadable).toList();
        final Set<String> selected = pool.toSet();
        return SettingsGroup(
          title: 'Books to draw from · ${SettingsLabels.books(selected.length)}',
          children: <Widget>[
            for (final HadithCollection collection in readable)
              _BookToggleRow(
                collection: collection,
                selected: selected.contains(collection.id),
                // The pool is never left empty: random mode would have nothing
                // to show.
                onChanged: selected.length == 1 &&
                        selected.contains(collection.id)
                    ? null
                    : (bool include) =>
                        _toggle(ref, readable, selected, collection, include),
              ),
          ],
        );
      },
    );
  }

  static Future<void> _toggle(
    WidgetRef ref,
    List<HadithCollection> readable,
    Set<String> selected,
    HadithCollection collection,
    bool include,
  ) async {
    final Set<String> next = <String>{...selected};
    include ? next.add(collection.id) : next.remove(collection.id);
    if (next.isEmpty) return;
    // Stored in catalog order, so the list reads the same way every time.
    final List<String> ordered = <String>[
      for (final HadithCollection c in readable)
        if (next.contains(c.id)) c.id,
    ];
    await ref.read(userPreferencesProvider.notifier).setRandomPool(ordered);
    await ref.read(todayControllerProvider.notifier).refresh();
  }
}

class _BookToggleRow extends StatelessWidget {
  const _BookToggleRow({
    required this.collection,
    required this.selected,
    required this.onChanged,
  });

  final HadithCollection collection;
  final bool selected;

  /// Null when this row cannot be switched off — it is the last book left.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<bool>? changed = onChanged;
    return SettingsRow(
      label: collection.titleEnglish,
      description: collection.compiler,
      onTap: changed == null ? null : () => changed(!selected),
      trailing: Checkbox(
        value: selected,
        onChanged: changed == null ? null : (bool? value) => changed(value ?? false),
        semanticLabel: collection.titleEnglish,
      ),
    );
  }
}
