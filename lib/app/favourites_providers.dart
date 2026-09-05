import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/favourite_hadith.dart';
import '../domain/entities/hadith.dart';
import '../domain/repositories/favourites_repository.dart';
import 'providers.dart';

/// Every saved hadith, newest first, across all collections.
final FutureProvider<List<FavouriteHadith>> favouritesProvider =
    FutureProvider<List<FavouriteHadith>>(
  (Ref ref) => ref.watch(favouritesRepositoryProvider).all(),
);

/// Whether one hadith is saved. Keyed by hadith id, which already carries the
/// collection, so two books cannot collide.
final isFavouriteProvider = FutureProvider.family<bool, Hadith>(
  (Ref ref, Hadith hadith) => ref
      .watch(favouritesRepositoryProvider)
      .isFavourite(hadith.collectionId, hadith.id),
);

/// Adds and removes favourites, invalidating the list so every screen showing
/// a heart updates at once.
class FavouritesController extends Notifier<void> {
  @override
  void build() {}

  Future<bool> toggle(Hadith hadith) async {
    final FavouritesRepository repository =
        ref.read(favouritesRepositoryProvider);
    final bool nowFavourite = await repository.toggle(
      hadith.collectionId,
      hadith.id,
      hadith.ordinal,
    );
    ref.invalidate(favouritesProvider);
    ref.invalidate(isFavouriteProvider(hadith));
    return nowFavourite;
  }
}

final NotifierProvider<FavouritesController, void> favouritesControllerProvider =
    NotifierProvider<FavouritesController, void>(FavouritesController.new);
