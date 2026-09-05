import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../local/progress_dao.dart';

/// Thin pass-through to [ProgressDao]. Kept as its own type so the domain layer
/// depends on an interface rather than on SQLite.
class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._dao);

  final ProgressDao _dao;

  @override
  Future<ReadingProgress> progressFor(String collectionId, int totalHadith) =>
      _dao.progressFor(collectionId, totalHadith);

  @override
  Future<List<ReadingProgress>> allProgress(Map<String, int> totals) =>
      _dao.allProgress(totals);

  @override
  Future<ReadingProgress> markRead(
    String collectionId,
    String hadithId,
    int ordinal,
    int totalHadith, {
    DateTime? at,
  }) =>
      _dao.markRead(collectionId, hadithId, ordinal, totalHadith, at: at);

  @override
  Future<ReadingProgress> markUnread(
    String collectionId,
    String hadithId,
    int totalHadith,
  ) =>
      _dao.markUnread(collectionId, hadithId, totalHadith);

  @override
  Future<ReadingProgress> setCurrentOrdinal(
    String collectionId,
    int ordinal,
    int totalHadith,
  ) =>
      _dao.setCurrentOrdinal(collectionId, ordinal, totalHadith);

  @override
  Future<bool> isRead(String collectionId, String hadithId) =>
      _dao.isRead(collectionId, hadithId);

  @override
  Future<Set<int>> readOrdinalsIn(String collectionId, int from, int to) =>
      _dao.readOrdinalsIn(collectionId, from, to);

  @override
  Future<int?> firstUnreadOrdinal(String collectionId, int totalHadith) =>
      _dao.firstUnreadOrdinal(collectionId, totalHadith);

  @override
  Future<ReadingProgress> resetCollection(
    String collectionId,
    int totalHadith,
  ) =>
      _dao.resetCollection(collectionId, totalHadith);
}
