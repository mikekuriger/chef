// screens/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/widgets/recipe_journal_widget.dart';
import 'package:chef/screens/recipe_edit_screen.dart';
import 'package:chef/theme/colors.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;
  // Bumped on every successful save so the key below always changes on
  // edit — not just when the title happens to change — forcing a fresh
  // RecipeJournalWidget state (and clearing its servings-override cache)
  // instead of reusing stale per-recipe scaler state from before the edit.
  int _editVersion = 0;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  Future<void> _editRecipe() async {
    final updated = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: _recipe)),
    );
    if (updated != null && mounted) {
      setState(() {
        _recipe = updated;
        _editVersion++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple900,
      appBar: AppBar(
        backgroundColor: AppColors.purple950,
        foregroundColor: Colors.white,
        elevation: 4,
        title: const Text(
          'My Recipe ✨',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Recipe',
            onPressed: _editRecipe,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RecipeJournalWidget(
          // Keyed by edit version (not just title) so ANY save forces a
          // fresh widget state — clearing stale scaler overrides too, not
          // just refreshing the displayed text.
          key: ValueKey('recipe-detail-${_recipe.id}-v$_editVersion'),
          filteredRecipes: [_recipe],
          autoExpandSingle: true,
          embeddedInScrollView: false,
        ),
      ),
    );
  }
}
