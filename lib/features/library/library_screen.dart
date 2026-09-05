import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../domain/entities/user_preferences.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/book_card.dart';
import '../../shared/widgets/state_views.dart';

/// Browse and switch between collections.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LibraryEntry>> entries = ref.watch(libraryProvider);
    final String? currentId = ref.watch(
      userPreferencesProvider
          .select((UserPreferences prefs) => prefs.currentCollectionId),
    );

    return AppPage(
      title: 'Hadith Library',
      child: entries.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'The library could not be loaded',
          message:
              'The list of collections is missing or unreadable. Your reading '
              'progress is safe.',
          onRetry: () => ref.invalidate(collectionsProvider),
        ),
        data: (List<LibraryEntry> value) {
          if (value.isEmpty) {
            return const EmptyStateView(
              icon: Icons.menu_book_outlined,
              message: 'Choose a collection to begin reading.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final LibraryEntry entry in value)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: BookCard(
                    entry: entry,
                    isCurrent: entry.collection.id == currentId,
                    onTap: () =>
                        context.go(Routes.collection(entry.collection.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
