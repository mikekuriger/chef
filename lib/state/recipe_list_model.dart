// state/recipe_list_model.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/repository/recipe_repository.dart';

class RecipeListModel extends ChangeNotifier {
  final RecipeRepository repo;
  final bool includeArchived;

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  StreamSubscription<List<Recipe>>? _sub;
  bool _loading = false;
  bool get loading => _loading;

  RecipeListModel({required this.repo, this.includeArchived = false});

  Future<void> init() async {
    _sub = repo.stream.listen((list) {
      _recipes = list;
      notifyListeners();
    });
    await repo.loadLocal(includeArchived: includeArchived);
    unawaited(refresh()); // kick remote sync
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true; notifyListeners();
    try {
      await repo.syncFromServer(includeArchived: includeArchived);
    } catch (e) {
      // Offline (or the request otherwise failed) - the local snapshot
      // loaded in init()/loadLocal() is already showing, so there's
      // nothing else to do here.
      debugPrint('⚠️ Recipe sync failed (offline?): $e');
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<void> deleteRecipe(int id) => repo.deleteRecipe(id, includeArchived: includeArchived);

  Future<void> upsertRecipe(Recipe r) => repo.upsertRecipe(r, includeArchived: includeArchived);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
