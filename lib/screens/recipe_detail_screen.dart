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
      setState(() => _recipe = updated);
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
          // Key it by the recipe's fields that change on edit, so the
          // journal widget rebuilds its internal state after a save
          // instead of reusing a stale list from before the edit.
          key: ValueKey('recipe-detail-${_recipe.id}-${_recipe.title.hashCode}'),
          filteredRecipes: [_recipe],
          autoExpandSingle: true,
          embeddedInScrollView: false,
        ),
      ),
    );
  }
}
