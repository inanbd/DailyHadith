import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/user_preferences.dart';
import '../features/library/collection_details_screen.dart';
import '../features/library/library_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/appearance_settings_screen.dart';
import '../features/settings/language_settings_screen.dart';
import '../features/settings/notification_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/today/today_screen.dart';
import 'bootstrap.dart';
import 'providers.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's router.
///
/// Two gates, applied in order: nothing renders until startup work has
/// finished, and nothing but onboarding renders until onboarding is done.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefresh refresh = _RouterRefresh();

  // Re-run the redirect whenever either gate changes.
  ref.listen(
    bootstrapProvider,
    (AsyncValue<BootstrapResult>? previous, AsyncValue<BootstrapResult> next) =>
        refresh.notify(),
  );
  ref.listen(
    userPreferencesProvider
        .select((UserPreferences prefs) => prefs.onboardingComplete),
    (bool? previous, bool next) => refresh.notify(),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool ready = ref.read(bootstrapProvider).hasValue;
      final String location = state.matchedLocation;

      if (!ready) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final bool onboarded =
          ref.read(userPreferencesProvider).onboardingComplete;
      if (!onboarded) {
        return location == Routes.onboarding ? null : Routes.onboarding;
      }

      // Startup screens have nothing left to do once both gates are open.
      if (location == Routes.splash || location == Routes.onboarding) {
        return Routes.today;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.today,
                builder: (BuildContext context, GoRouterState state) =>
                    const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.library,
                builder: (BuildContext context, GoRouterState state) =>
                    const LibraryScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: '${Routes.collectionSegment}/:collectionId',
                    builder: (BuildContext context, GoRouterState state) =>
                        CollectionDetailsScreen(
                      collectionId:
                          state.pathParameters['collectionId'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.favourites,
                builder: (BuildContext context, GoRouterState state) =>
                    const FavouritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.progress,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.settings,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'notifications',
                    builder: (BuildContext context, GoRouterState state) =>
                        const NotificationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'language',
                    builder: (BuildContext context, GoRouterState state) =>
                        const LanguageSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'appearance',
                    builder: (BuildContext context, GoRouterState state) =>
                        const AppearanceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (BuildContext context, GoRouterState state) =>
                        const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod changes to GoRouter's [Listenable]-based refresh.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
