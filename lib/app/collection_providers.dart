import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../domain/entities/hadith_collection.dart';
import '../domain/entities/user_preferences.dart';
import '../domain/entities/reading_progress.dart';
import '../domain/repositories/progress_repository.dart';
import 'providers.dart';

/// Every collection in the catalog, with local install state resolved.
final FutureProvider<List<HadithCollection>> collectionsProvider =
    FutureProvider<List<HadithCollection>>(
  (Ref ref) => ref.watch(hadithRepositoryProvider).collections(),
);

/// A collection paired with the reader's progress in it.
@immutable
class LibraryEntry {
  const LibraryEntry({required this.collection, required this.progress});

  final HadithCollection collection;
  final ReadingProgress progress;

  bool get hasStarted => progress.hasStarted || progress.totalRead > 0;
}

/// The library list: catalog order, each entry carrying its own progress.
final FutureProvider<List<LibraryEntry>> libraryProvider =
    FutureProvider<List<LibraryEntry>>((Ref ref) async {
  final List<HadithCollection> collections =
      await ref.watch(collectionsProvider.future);
  final ProgressRepository progressRepository =
      ref.watch(progressRepositoryProvider);

  final List<LibraryEntry> entries = <LibraryEntry>[];
  for (final HadithCollection collection in collections) {
    entries.add(
      LibraryEntry(
        collection: collection,
        progress: await progressRepository.progressFor(
          collection.id,
          collection.totalHadith,
        ),
      ),
    );
  }
  return entries;
});

/// Only the collections the reader has actually started, most recent first.
/// Backs the Progress screen.
final FutureProvider<List<LibraryEntry>> startedCollectionsProvider =
    FutureProvider<List<LibraryEntry>>((Ref ref) async {
  final List<LibraryEntry> entries = await ref.watch(libraryProvider.future);
  final List<LibraryEntry> started =
      entries.where((LibraryEntry entry) => entry.hasStarted).toList();
  started.sort((LibraryEntry a, LibraryEntry b) {
    final DateTime? left = a.progress.lastReadAt;
    final DateTime? right = b.progress.lastReadAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
  return started;
});

/// A single collection by id, or null when the catalog has no such entry.
final collectionProvider =
    FutureProvider.family<HadithCollection?, String>(
  (Ref ref, String id) async {
    final List<HadithCollection> collections =
        await ref.watch(collectionsProvider.future);
    for (final HadithCollection collection in collections) {
      if (collection.id == id) return collection;
    }
    return null;
  },
);

/// Progress for a single collection.
final collectionProgressProvider =
    FutureProvider.family<ReadingProgress, String>((Ref ref, String id) async {
  final HadithCollection? collection =
      await ref.watch(collectionProvider(id).future);
  return ref.watch(progressRepositoryProvider).progressFor(
        id,
        collection?.totalHadith ?? 0,
      );
});

/// The book the Today screen reads from.
final FutureProvider<HadithCollection?> currentCollectionProvider =
    FutureProvider<HadithCollection?>((Ref ref) async {
  final String? id = ref.watch(
    userPreferencesProvider
        .select((UserPreferences prefs) => prefs.currentCollectionId),
  );
  if (id == null) return null;
  return ref.watch(collectionProvider(id).future);
});
