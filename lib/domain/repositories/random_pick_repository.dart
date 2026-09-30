import '../entities/random_pick.dart';

/// Which hadith random mode has chosen for each reading period.
///
/// Picks are stored rather than recomputed so a reminder that previewed a
/// hadith, and the app opened from it, always agree on which one it was.
abstract interface class RandomPickRepository {
  Future<RandomPick?> pickFor(DateTime periodStart);

  /// Every pick for a period starting at or after [from], earliest first.
  Future<List<RandomPick>> picksFrom(DateTime from);

  /// Stores [pick], replacing any pick already made for its period.
  Future<void> save(RandomPick pick);

  Future<void> saveAll(List<RandomPick> picks);

  /// Forgets picks for periods starting at or after [from] — used when the
  /// books random mode draws from change, so nothing stale is shown.
  Future<void> deleteFrom(DateTime from);

  /// Forgets picks for periods that started before [before].
  Future<void> deleteBefore(DateTime before);
}
