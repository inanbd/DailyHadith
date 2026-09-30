import 'package:daily_hadith/data/local/preferences_store.dart';
import 'package:daily_hadith/domain/entities/enums.dart';
import 'package:daily_hadith/domain/entities/notification_preferences.dart';
import 'package:daily_hadith/domain/entities/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<PreferencesStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return PreferencesStore(await SharedPreferences.getInstance());
  }

  test('several reminder times survive a round trip', () async {
    final PreferencesStore store = await storeWith(<String, Object>{});
    final NotificationPreferences saved =
        NotificationPreferences.defaults.copyWith(
      enabled: true,
      times: <TimeOfDayValue>[
        const TimeOfDayValue(21, 15),
        const TimeOfDayValue(6, 0),
      ],
      showHadithPreview: false,
    );
    await store.saveNotificationPreferences(saved);

    final NotificationPreferences loaded =
        await store.loadNotificationPreferences();
    expect(loaded.times, const <TimeOfDayValue>[
      TimeOfDayValue(6, 0),
      TimeOfDayValue(21, 15),
    ]);
    expect(loaded.showHadithPreview, isFalse);
  });

  test('a single time saved by an earlier version is still read', () async {
    final PreferencesStore store = await storeWith(<String, Object>{
      'flutter.notify.time': '07:45',
    });
    final NotificationPreferences loaded =
        await store.loadNotificationPreferences();
    expect(loaded.times, const <TimeOfDayValue>[TimeOfDayValue(7, 45)]);
    // Earlier versions had no choice, and previews are the new default.
    expect(loaded.showHadithPreview, isTrue);
  });

  test('malformed times are dropped rather than turned into 8:00 AM', () async {
    final PreferencesStore store = await storeWith(<String, Object>{
      'flutter.notify.times': <String>['09:00', 'nonsense', '25:00'],
    });
    final NotificationPreferences loaded =
        await store.loadNotificationPreferences();
    expect(loaded.times, const <TimeOfDayValue>[TimeOfDayValue(9, 0)]);
  });

  test('the books random mode draws from survive a round trip', () async {
    final PreferencesStore store = await storeWith(<String, Object>{});
    await store.saveUserPreferences(
      UserPreferences.defaults.copyWith(
        readingOrder: ReadingOrder.random,
        currentCollectionId: 'a',
        randomCollectionIds: <String>['b', 'c'],
      ),
    );
    final UserPreferences loaded = await store.loadUserPreferences();
    expect(loaded.isRandom, isTrue);
    expect(loaded.randomPool, <String>['b', 'c']);
  });

  test('random mode draws from the current book until books are chosen', () {
    final UserPreferences preferences =
        UserPreferences.defaults.copyWith(currentCollectionId: 'a');
    expect(preferences.randomPool, <String>['a']);
  });
}
