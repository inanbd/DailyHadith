import '../core/utils/formatting.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/hadith.dart';
import '../domain/entities/hadith_collection.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/entities/random_pick.dart';
import '../domain/entities/reading_progress.dart';
import '../domain/entities/user_preferences.dart';
import '../domain/repositories/hadith_repository.dart';
import '../domain/repositories/notification_scheduler.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/services/reading_scheduler.dart';
import '../domain/services/reminder_schedule.dart';
import 'random_selection.dart';

/// Decides which hadith each upcoming reminder carries.
///
/// **In order**, reminder *k* carries the *k*-th unread hadith after the one on
/// screen now — what the reader reaches if they read each hadith as it
/// arrives. Tapping a reminder opens exactly the hadith it showed, and the plan
/// is rebuilt whenever the app runs or a hadith is marked, so it never drifts
/// far from the reader's real progress.
///
/// **Random**, each reminder starts a reading period, and carries that
/// period's pick. The pick is stored, so the app shows the same hadith when
/// the period arrives.
class ReminderPlanner {
  ReminderPlanner({
    required HadithRepository hadithRepository,
    required ProgressRepository progressRepository,
    required RandomSelection randomSelection,
  })  : _hadith = hadithRepository,
        _progress = progressRepository,
        _random = randomSelection;

  final HadithRepository _hadith;
  final ProgressRepository _progress;
  final RandomSelection _random;

  /// How many reminders to plan ahead. Matches the scheduler's window, which
  /// stays under iOS's cap on pending notifications.
  static const int window = 60;

  static const int _bodyLength = 180;
  static const int _expandedLength = 1200;

  Future<List<PlannedReminder>> plan({
    required NotificationPreferences notifications,
    required UserPreferences user,
    required DateTime now,
  }) async {
    if (!notifications.enabled) return const <PlannedReminder>[];
    final List<DateTime> occurrences =
        ReminderSchedule(notifications).nextOccurrences(now, count: window);
    if (occurrences.isEmpty) return const <PlannedReminder>[];

    return user.isRandom
        ? _planRandom(
            occurrences,
            ReminderSchedule(notifications).currentPeriodStart(now),
            user,
          )
        : _planInOrder(occurrences, user, notifications, now);
  }

  Future<List<PlannedReminder>> _planInOrder(
    List<DateTime> occurrences,
    UserPreferences user,
    NotificationPreferences notifications,
    DateTime now,
  ) async {
    final String? collectionId = user.currentCollectionId;
    if (collectionId == null) return const <PlannedReminder>[];
    final HadithCollection collection =
        await _hadith.installCollection(collectionId);
    final int total = collection.totalHadith;
    if (total <= 0) return const <PlannedReminder>[];

    final ReadingProgress progress =
        await _progress.progressFor(collectionId, total);
    final int onScreen = ReadingScheduler.resolveTodaysOrdinal(
      progress: progress,
      firstUnreadOrdinal: await _progress.firstUnreadOrdinal(collectionId, total),
      notificationPreferences: notifications,
      now: now,
    );
    final Set<int> read = await _progress.readOrdinalsIn(collectionId, 1, total);

    final List<PlannedReminder> planned = <PlannedReminder>[];
    int ordinal = 0;
    for (final DateTime at in occurrences) {
      // The next unread hadith that is not the one already on screen, which
      // belongs to the current period.
      do {
        ordinal++;
      } while (ordinal <= total && (read.contains(ordinal) || ordinal == onScreen));

      final Hadith? hadith =
          ordinal <= total ? await _hadith.hadithAt(collectionId, ordinal) : null;
      // Past the end of the book there is nothing new to carry; the reminder
      // still comes, as a plain invitation.
      planned.add(
        hadith == null
            ? _invitation(at, collection)
            : _forHadith(at, collection, hadith, user.languageMode),
      );
    }
    return planned;
  }

  Future<List<PlannedReminder>> _planRandom(
    List<DateTime> occurrences,
    DateTime currentPeriod,
    UserPreferences user,
  ) async {
    final List<HadithCollection> pool =
        await _random.readablePool(user.randomPool);
    if (pool.isEmpty) return const <PlannedReminder>[];

    // The period under way is picked first, if it has no pick yet, so the
    // hadith on screen now takes part in the round like any other and is not
    // drawn again for the next reminder.
    final List<RandomPick> picks = (await _random.picksFor(
      <DateTime>[currentPeriod, ...occurrences],
      pool,
    ))
        .where((RandomPick pick) => pick.periodStart != currentPeriod)
        .toList();
    final Map<String, HadithCollection> installed = <String, HadithCollection>{};

    final List<PlannedReminder> planned = <PlannedReminder>[];
    for (final RandomPick pick in picks) {
      final HadithCollection collection = installed[pick.collectionId] ??=
          await _hadith.installCollection(pick.collectionId);
      final Hadith? hadith =
          await _hadith.hadithAt(pick.collectionId, pick.ordinal);
      planned.add(
        hadith == null
            ? _invitation(pick.periodStart, collection)
            : _forHadith(
                pick.periodStart,
                collection,
                hadith,
                user.languageMode,
              ),
      );
    }
    return planned;
  }

  static PlannedReminder _forHadith(
    DateTime at,
    HadithCollection collection,
    Hadith hadith,
    LanguageMode language,
  ) {
    // The translation reads best in a notification; the Arabic is used when
    // that is what the reader reads, or all the source has.
    final bool english = hadith.hasEnglish &&
        (language.showsEnglish || !hadith.hasArabic);
    final String text = english ? hadith.englishText! : hadith.arabicText!;
    return PlannedReminder(
      at: at,
      title: '${collection.titleEnglish} · Hadith ${hadith.hadithNumber}',
      body: Formatting.excerpt(text, _bodyLength),
      expandedBody: Formatting.excerpt(text, _expandedLength),
      link: HadithDeepLink(
        collectionId: collection.id,
        ordinal: hadith.ordinal,
      ),
    );
  }

  static PlannedReminder _invitation(DateTime at, HadithCollection collection) {
    final String body = 'Your next hadith from ${collection.titleEnglish} '
        'is ready.';
    return PlannedReminder(
      at: at,
      title: 'Today’s Hadith',
      body: body,
      expandedBody: body,
      link: HadithDeepLink(collectionId: collection.id),
    );
  }
}
