import '../entities/reading_progress.dart';

/// Per-collection reading progress. Progress for a collection is never cleared
/// by switching books.
abstract interface class ProgressRepository {
  Future<ReadingProgress> progressFor(String collectionId, int totalHadith);

  /// Progress for every collection that has been started.
  Future<List<ReadingProgress>> allProgress(Map<String, int> totalsByCollection);

  /// Marks a single hadith read. Only this hadith — hadith skipped over are
  /// deliberately left unread.
  Future<ReadingProgress> markRead(
    String collectionId,
    String hadithId,
    int ordinal,
    int totalHadith, {
    DateTime? at,
  });

  Future<ReadingProgress> markUnread(
    String collectionId,
    String hadithId,
    int totalHadith,
  );

  /// Moves the reader's position without changing read state.
  Future<ReadingProgress> setCurrentOrdinal(
    String collectionId,
    int ordinal,
    int totalHadith,
  );

  Future<bool> isRead(String collectionId, String hadithId);

  /// Read state for a window of ordinals, for list rendering.
  Future<Set<int>> readOrdinalsIn(String collectionId, int from, int to);

  /// The lowest unread ordinal, or null when the collection is finished.
  Future<int?> firstUnreadOrdinal(String collectionId, int totalHadith);

  /// Clears all read state for a collection so it can be read again.
  Future<ReadingProgress> resetCollection(String collectionId, int totalHadith);
}
