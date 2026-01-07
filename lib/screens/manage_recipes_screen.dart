// screens/manage_recipes_screen.dart
import 'package:chef/screens/recipe_journal_editor_screen.dart';
import 'package:chef/theme/colors.dart';
import 'package:flutter/material.dart';

class ManageRecipesScreen extends StatelessWidget {
  final ValueNotifier<int> refreshTrigger;

  const ManageRecipesScreen({
    super.key,
    required this.refreshTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.purple950,
        foregroundColor: Colors.white,
        elevation: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Recipes ✏️',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Hide or delete recipes',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.headerSubtitle,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: RecipeJournalEditorScreen(refreshTrigger: refreshTrigger),
      ),
    );
  }
}
