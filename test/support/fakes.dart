import 'dart:async';
import 'dart:convert';
import 'package:daily_hadith/domain/entities/chapter.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/repositories/hadith_content_source.dart';
import 'package:daily_hadith/domain/repositories/notification_scheduler.dart';
import 'package:daily_hadith/domain/repositories/speech_synthesizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An in-memory content source, so tests never depend on bundled assets.
class FakeContentSource implements HadithContentSource {
  FakeContentSource({
    required this.collections,
    required this.hadithByCollection,
    this.chaptersByCollection = const <String, List<HadithChapter>>{},
  });

  /// A single collection of [count] entries, numbered 1..count.
  factory FakeContentSource.single({
    String id = 'test_collection',
    String title = 'Test Collection',
    int count = 10,
    ContentVerification verification = ContentVerification.verified,
    String Function(int ordinal)? englishText,
  }) {
    final HadithCollection collection = HadithCollection(
      id: id,
      slug: id,
      titleEnglish: title,
      titleArabic: 'مجموعة',
      compiler: 'Test compiler',
      description: 'A collection used by the test suite.',
      totalHadith: count,
      source: const ContentSource(name: 'Test fixture'),
      verification: verification,
    );
    return FakeContentSource(
      collections: <HadithCollection>[collection],
      hadithByCollection: <String, List<Hadith>>{
        id: <Hadith>[
          for (int i = 1; i <= count; i++)
            Hadith(
              id: '$id:$i',
              collectionId: id,
              ordinal: i,
              hadithNumber: '$i',
              chapterNumber: 1,
              chapterEnglish: 'Test chapter',
              arabicText: 'نص عربي رقم $i',
              englishText: englishText?.call(i) ?? 'English text number $i.',
              narrator: 'Test narrator',
              reference: '$title $i',
            ),
        ],
      },
    );
  }

  final List<HadithCollection> collections;
  final Map<String, List<Hadith>> hadithByCollection;
  final Map<String, List<HadithChapter>> chaptersByCollection;

  int loadHadithCalls = 0;

  @override
  Future<List<HadithCollection>> loadCatalog() async => collections;

  @override
  Future<bool> hasContentFor(String collectionId) async =>
      hadithByCollection.containsKey(collectionId);

  @override
  Future<List<Hadith>> loadHadith(String collectionId) async {
    loadHadithCalls++;
    final List<Hadith>? hadith = hadithByCollection[collectionId];
    if (hadith == null) throw StateError('no content for $collectionId');
    return hadith;
  }

  @override
  Future<List<HadithChapter>> loadChapters(String collectionId) async =>
      chaptersByCollection[collectionId] ?? const <HadithChapter>[];
}

/// Records what the app asked the platform to schedule, without touching a
/// real notification plugin.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.status = NotificationPermissionStatus.granted,
    this.otherRequirements = allSatisfied,
    this.grantsOnRequest = true,
    this.launchDeepLink,
  });

  /// A platform with nothing to ask for beyond notification permission, which
  /// is all most tests care about.
  static const ReminderReadiness allSatisfied = ReminderReadiness(
    notifications: NotificationPermissionStatus.granted,
    exactTiming: NotificationPermissionStatus.unsupported,
    background: NotificationPermissionStatus.unsupported,
  );

  /// An Android-shaped platform where punctuality still has to be asked for.
  static const ReminderReadiness androidUnasked = ReminderReadiness(
    notifications: NotificationPermissionStatus.granted,
    exactTiming: NotificationPermissionStatus.denied,
    background: NotificationPermissionStatus.denied,
  );

  /// Notification permission, as the shorthand most tests care about.
  NotificationPermissionStatus status;

  /// Whether a prompt is answered yes. False stands in for a reader who
  /// declines, or an OS that has stopped showing the prompt at all.
  bool grantsOnRequest;

  HadithDeepLink? launchDeepLink;

  /// Everything except notification permission, which [status] owns.
  ReminderReadiness otherRequirements;

  final List<NotificationPreferences> scheduledPreferences =
      <NotificationPreferences>[];
  final List<String?> scheduledCollectionIds = <String?>[];
  final List<ReminderRequirement> requested = <ReminderRequirement>[];
  int cancelAllCalls = 0;
  int settingsOpened = 0;
  bool initialized = false;

  /// How many times the OS notification prompt was raised.
  int get permissionRequests => requested
      .where((ReminderRequirement it) => it == ReminderRequirement.notifications)
      .length;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<ReminderReadiness> readiness() async =>
      otherRequirements.copyWith(notifications: status);

  @override
  Future<bool> request(ReminderRequirement requirement) async {
    requested.add(requirement);
    if (!grantsOnRequest) return false;
    switch (requirement) {
      case ReminderRequirement.notifications:
        status = NotificationPermissionStatus.granted;
      case ReminderRequirement.exactTiming:
        otherRequirements = otherRequirements
            .copyWith(exactTiming: NotificationPermissionStatus.granted);
      case ReminderRequirement.background:
        otherRequirements = otherRequirements
            .copyWith(background: NotificationPermissionStatus.granted);
    }
    return true;
  }

  @override
  Future<bool> openSystemNotificationSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<void> reschedule({
    required NotificationPreferences preferences,
    required String? collectionId,
    required String? collectionTitle,
  }) async {
    scheduledPreferences.add(preferences);
    scheduledCollectionIds.add(collectionId);
  }

  @override
  Future<void> cancelAll() async => cancelAllCalls++;

  @override
  Future<HadithDeepLink?> consumeLaunchDeepLink() async {
    final HadithDeepLink? link = launchDeepLink;
    launchDeepLink = null;
    return link;
  }

  @override
  Stream<HadithDeepLink> get deepLinks => const Stream<HadithDeepLink>.empty();

  @override
  Future<int> pendingCount() async => scheduledPreferences.length;
}

/// An [AssetBundle] backed by a map, for exercising the real asset parser.
class MapAssetBundle extends CachingAssetBundle {
  MapAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final String? value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

/// A [SpeechSynthesizer] that records what it was asked to say.
///
/// Speaking completes immediately, so a test never has to wait on a real
/// engine; [completeManually] holds the utterance open when a test needs to
/// observe the speaking state.
class FakeSpeechSynthesizer implements SpeechSynthesizer {
  FakeSpeechSynthesizer({
    this.available = true,
    this.unavailableLanguages = const <String>{},
    this.completeManually = false,
  });

  /// Whether the device claims any voice at all.
  bool available;

  /// Languages this device specifically lacks, for the common real case of an
  /// English voice installed and an Arabic one not.
  Set<String> unavailableLanguages;

  /// When true, [speak] does not complete until [finish] is called.
  bool completeManually;

  final List<String> spoken = <String>[];
  final List<String> languages = <String>[];
  int stopCalls = 0;
  int disposeCalls = 0;

  Completer<void>? _pending;

  @override
  Future<bool> isLanguageAvailable(String languageCode) async =>
      available && !unavailableLanguages.contains(languageCode);

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    spoken.add(text);
    languages.add(languageCode);
    if (!completeManually) return;
    final Completer<void> completer = Completer<void>();
    _pending = completer;
    return completer.future;
  }

  /// Completes an utterance held open by [completeManually].
  void finish() {
    _pending?.complete();
    _pending = null;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _pending?.complete();
    _pending = null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
