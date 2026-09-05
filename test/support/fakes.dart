import 'dart:convert';
import 'package:daily_hadith/domain/entities/chapter.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/hadith.dart';
import 'package:daily_hadith/domain/entities/hadith_collection.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/repositories/hadith_content_source.dart';
import 'package:daily_hadith/domain/repositories/notification_scheduler.dart';
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
              englishText: 'English text number $i.',
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
    this.launchDeepLink,
  });

  NotificationPermissionStatus status;
  HadithDeepLink? launchDeepLink;

  final List<NotificationPreferences> scheduledPreferences =
      <NotificationPreferences>[];
  final List<String?> scheduledCollectionIds = <String?>[];
  int cancelAllCalls = 0;
  int permissionRequests = 0;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => status;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    status = NotificationPermissionStatus.granted;
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
