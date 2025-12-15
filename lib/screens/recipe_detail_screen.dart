// screens/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/widgets/recipe_journal_widget.dart';
import 'package:chef/theme/colors.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

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
      ),
      body: SafeArea(
        top: false,
        child: RecipeJournalWidget(
          filteredRecipes: [recipe],
          autoExpandSingle: true,
          embeddedInScrollView: false,
        ),
      ),
    );
  }
}
