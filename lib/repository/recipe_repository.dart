// repository/recipe_repository.dart
import 'dart:async';
import 'package:chef/models/recipe.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/data/recipe_dao.dart';

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
  /// Per-recipe images are cached lazily on view (see localFirstImage in
  /// recipe_journal_widget.dart), not prefetched in bulk here.
  Future<void> syncFromServer({bool includeArchived = false}) async {
    final remote = includeArchived
        ? await ApiService.fetchAllRecipes()
        : await ApiService.fetchRecipes();

    await _dao.upsertMany(remote);

    final updated = await _dao.getAll(includeArchived: includeArchived);
    _controller.add(updated);
  }

  /// Deletes on the server first, then locally, so a failed server delete
  /// (e.g. offline) doesn't remove a recipe the server still has.
  Future<void> deleteRecipe(int id, {bool includeArchived = false}) async {
    await ApiService.deleteRecipe(id);
    await _dao.deleteById(id);
    _controller.add(await _dao.getAll(includeArchived: includeArchived));
  }

  /// Writes a single recipe (freshly created or just edited) straight into
  /// the local cache and re-emits, so it's available offline immediately
  /// instead of waiting for the next full syncFromServer.
  Future<void> upsertRecipe(Recipe r, {bool includeArchived = false}) async {
    await _dao.upsert(r);
    _controller.add(await _dao.getAll(includeArchived: includeArchived));
  }

  void dispose() => _controller.close();
}
