// repository/recipe_repository.dart
import 'dart:async';
import 'package:chef/models/recipe.dart';
import 'package:chef/services/api_service.dart';
// import 'package:chef/services/image_store.dart';
import 'package:chef/data/recipe_dao.dart';
// import 'package:chef/services/dio_client.dart';

class RecipeRepository {
  final _dao = RecipeDao();
  final _controller = StreamController<List<Recipe>>.broadcast();
  Stream<List<Recipe>> get stream => _controller.stream;

  /// === KEEP EXISTING NAME: used by RecipeListModel ===
  Future<List<Recipe>> loadLocal({bool includeArchived = false}) async {
    final local = await _dao.getAll(includeArchived: includeArchived);
    _controller.add(local);
    return local;
  }

  /// === KEEP EXISTING NAME: used by RecipeListModel ===
  /// Local-first: updates DB from server, then emits new local snapshot.
  Future<void> syncFromServer({
    bool includeArchived = false,
    bool prefetchImages = true,
  }) async {
    // Use existing endpoints only (no updatedSince yet).
    final remote = includeArchived
        ? await ApiService.fetchAllRecipes()
        : await ApiService.fetchRecipes();

    await _dao.upsertMany(remote);

    // if (prefetchImages) {
    //   for (final d in remote) {
    //     // These helpers are already defined in your ImageStore
    //     await ImageStore.prefetchForRecipe(
    //       recipeId: d.id,
    //       imageFileUrl: d.imageFile,
    //       imageTileUrl: d.imageTile,
    //       dio: DioClient.dio, // pass shared Dio for auth/cookies
    //     );
    //   }
    // }

    final updated = await _dao.getAll(includeArchived: includeArchived);
    _controller.add(updated);
  }

  void dispose() => _controller.close();
}
