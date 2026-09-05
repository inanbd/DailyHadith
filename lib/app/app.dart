import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/enums.dart';
import '../domain/entities/user_preferences.dart';
import '../domain/repositories/notification_scheduler.dart';
import '../features/today/today_controller.dart';
import '../shared/theme/app_theme.dart';
import 'bootstrap.dart';
import 'providers.dart';
import 'router.dart';
import 'routes.dart';

/// Application root.
///
/// Beyond building the [MaterialApp] it owns two cross-cutting behaviours:
/// following notification taps to the right book, and refreshing when the app
/// comes back to the foreground.
class DailyHadithApp extends ConsumerStatefulWidget {
  const DailyHadithApp({super.key});

  @override
  ConsumerState<DailyHadithApp> createState() => _DailyHadithAppState();
}

class _DailyHadithAppState extends ConsumerState<DailyHadithApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The reader may have changed notification permission in system settings,
    // and enough time may have passed for the book to move on.
    ref.invalidate(notificationPermissionProvider);
    ref.read(todayControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final AppThemeMode themeMode = ref.watch(
      userPreferencesProvider.select((UserPreferences prefs) => prefs.themeMode),
    );

    // A reminder tapped while the app was terminated.
    ref.listen(bootstrapProvider, (
      AsyncValue<BootstrapResult>? previous,
      AsyncValue<BootstrapResult> next,
    ) {
      final HadithDeepLink? link = next.value?.launchDeepLink;
      if (link != null) _openFromReminder(link);
    });

    // A reminder tapped while the app was running.
    ref.listen(deepLinkStreamProvider, (
      AsyncValue<HadithDeepLink>? previous,
      AsyncValue<HadithDeepLink> next,
    ) {
      final HadithDeepLink? link = next.value;
      if (link != null) _openFromReminder(link);
    });

    return MaterialApp.router(
      title: 'Daily Hadith',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      builder: (BuildContext context, Widget? child) {
        // Respect the platform's dynamic type, but keep it inside a range the
        // reading layout can still honour.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Opens the reminder's collection at the reader's current position, and
  /// marks that hadith read.
  ///
  /// The notification firing changed nothing; arriving here — the reader
  /// actually opening it — is what counts as reading it.
  Future<void> _openFromReminder(HadithDeepLink link) async {
    final String? currentId =
        ref.read(userPreferencesProvider).currentCollectionId;
    if (link.collectionId != currentId) {
      await ref
          .read(userPreferencesProvider.notifier)
          .setCurrentCollection(link.collectionId);
    }

    ref.read(routerProvider).go(Routes.today);
    await ref.read(todayControllerProvider.notifier).markReadFromNotification();
  }
}
