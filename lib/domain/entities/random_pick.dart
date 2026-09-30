import 'package:meta/meta.dart';

/// The hadith random mode shows for one reading period.
@immutable
class RandomPick {
  const RandomPick({
    required this.periodStart,
    required this.collectionId,
    required this.ordinal,
  });

  /// The moment the reading period began: a reminder time, or the daily
  /// boundary when reminders are off.
  final DateTime periodStart;

  final String collectionId;

  /// Reading position of the hadith within [collectionId].
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      other is RandomPick &&
      other.periodStart == periodStart &&
      other.collectionId == collectionId &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(periodStart, collectionId, ordinal);

  @override
  String toString() => 'RandomPick($periodStart, $collectionId:$ordinal)';
}
