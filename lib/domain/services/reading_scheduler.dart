import '../entities/notification_preferences.dart';
import '../entities/reading_progress.dart';
import 'reminder_schedule.dart';

/// Decides which hadith the Today screen should show.
///
/// The rule, in one sentence: stay on what you read this period, otherwise move
/// to the first hadith you have not read.
///
/// This is what makes missed days behave gently. Nothing is ever marked read
/// because time passed or because a notification fired — a reader who skips a
/// week comes back to exactly the hadith they left unread.
abstract final class ReadingScheduler {
  /// The ordinal the Today screen opens on.
  ///
  /// [firstUnreadOrdinal] is null when every hadith has been read.
  static int resolveTodaysOrdinal({
    required ReadingProgress progress,
    required int? firstUnreadOrdinal,
    required NotificationPreferences notificationPreferences,
    required DateTime now,
  }) {
    final int total = progress.totalHadith;
    if (total <= 0) return 1;

    // Finished books stay on their last hadith rather than wrapping around.
    if (firstUnreadOrdinal == null) {
      return progress.currentOrdinal.clamp(1, total);
    }

    final DateTime? lastReadAt = progress.lastReadAt;
    if (lastReadAt == null) {
      // Nothing read yet: begin at the first unread hadith.
      return firstUnreadOrdinal.clamp(1, total);
    }

    final DateTime periodStart =
        ReminderSchedule(notificationPreferences).currentPeriodStart(now);

    if (lastReadAt.isBefore(periodStart)) {
      // A new reading period began since the last time anything was read, so
      // the book moves on to the next thing they have not read.
      return firstUnreadOrdinal.clamp(1, total);
    }

    // Already read within this period — hold position so re-opening the app
    // shows what they just read instead of jumping ahead.
    return progress.currentOrdinal.clamp(1, total);
  }
}
