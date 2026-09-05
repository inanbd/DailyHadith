import 'package:meta/meta.dart';

/// Per-collection reading state.
///
/// Each collection keeps its own progress, so switching books never discards
/// where the reader was.
@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.collectionId,
    required this.currentOrdinal,
    required this.totalRead,
    required this.totalHadith,
    this.startedAt,
    this.lastReadAt,
    this.completedAt,
  });

  /// A collection that has never been opened.
  factory ReadingProgress.empty(String collectionId, int totalHadith) {
    return ReadingProgress(
      collectionId: collectionId,
      currentOrdinal: 1,
      totalRead: 0,
      totalHadith: totalHadith,
    );
  }

  final String collectionId;

  /// Where the reader is right now (1-based). Moves when the reader navigates
  /// and when a new reading period rolls the book forward.
  final int currentOrdinal;

  /// How many hadith in this collection are marked read.
  final int totalRead;

  /// Size of the collection, for percentage and completion checks.
  final int totalHadith;

  final DateTime? startedAt;
  final DateTime? lastReadAt;

  /// Set once every hadith in the collection has been read.
  final DateTime? completedAt;

  bool get hasStarted => startedAt != null;
  bool get isComplete => totalHadith > 0 && totalRead >= totalHadith;

  /// 0.0–1.0. Guards against a zero-length collection.
  double get fraction {
    if (totalHadith <= 0) return 0;
    return (totalRead / totalHadith).clamp(0.0, 1.0);
  }

  /// Percentage rounded to one decimal, e.g. `12.8`.
  double get percentage => double.parse((fraction * 100).toStringAsFixed(1));

  /// Average hadith read per day since starting, or null when there is not yet
  /// enough history to say anything meaningful.
  double? get pacePerDay {
    final DateTime? start = startedAt;
    if (start == null || totalRead < 2) return null;
    final DateTime end = lastReadAt ?? DateTime.now();
    final double days = end.difference(start).inMinutes / (60 * 24);
    if (days < 1) return null;
    return totalRead / days;
  }

  /// Projected finish date. Null unless a pace can be established and there is
  /// something left to read — an estimate is only shown when it means something.
  DateTime? get estimatedCompletion {
    if (isComplete) return null;
    final double? pace = pacePerDay;
    if (pace == null || pace <= 0) return null;
    final int remaining = totalHadith - totalRead;
    final int daysLeft = (remaining / pace).ceil();
    if (daysLeft > 365 * 20) return null;
    return DateTime.now().add(Duration(days: daysLeft));
  }

  ReadingProgress copyWith({
    int? currentOrdinal,
    int? totalRead,
    int? totalHadith,
    DateTime? startedAt,
    DateTime? lastReadAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return ReadingProgress(
      collectionId: collectionId,
      currentOrdinal: currentOrdinal ?? this.currentOrdinal,
      totalRead: totalRead ?? this.totalRead,
      totalHadith: totalHadith ?? this.totalHadith,
      startedAt: startedAt ?? this.startedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
