// widgets/recipe_journal_editor_widget.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/services/api_service.dart';
// import 'package:intl/intl.dart';
// import 'package:chef/widgets/recipe_image.dart.NO';
import 'package:chef/services/image_store.dart'; // for RecipeImageKind



class RecipeJournalEditorWidget extends StatefulWidget {
  final VoidCallback? onRecipesLoaded;

  const RecipeJournalEditorWidget({
    super.key,
    this.onRecipesLoaded,
  });

  @override
  State<RecipeJournalEditorWidget> createState() => RecipeJournalEditorWidgetState();
}

class ToneStyle {
  final Color background;
  final Color text;
  const ToneStyle(this.background, this.text);
}

class RecipeJournalEditorWidgetState extends State<RecipeJournalEditorWidget> {
  
  List<Recipe> _recipes = [];
  List<Recipe> getRecipes() => _recipes;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  
  ToneStyle _getToneStyle(String categories) {
    final t = categories.toLowerCase().trim();
    switch (t) {
      case 'peaceful / gentle':
        return ToneStyle(Colors.blue.shade100, Colors.black87);
      case 'epic / heroic':
        return ToneStyle(Colors.orange.shade100, Colors.black87);
      case 'whimsical / surreal':
        return ToneStyle(Colors.purple.shade100, Colors.black87);
      case 'nightmarish / dark':
        // return ToneStyle(Colors.black, Colors.red.shade500);  // 👈 spooky red
        return ToneStyle(Colors.grey.shade900, Colors.orange.shade200);  // 👈 spooky red
      case 'romantic / nostalgic':
        return ToneStyle(Colors.pink.shade100, Colors.black87);
      case 'ancient / mythic':
        return ToneStyle(Colors.brown.shade100, Colors.black87);
      case 'futuristic / uncanny':
        return ToneStyle(Colors.teal.shade100, Colors.black87);
      case 'elegant / ornate':
        return ToneStyle(Colors.indigo.shade100, Colors.black87);
      default:
        return ToneStyle(Colors.grey.shade100, Colors.black87);
    }
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await ApiService.fetchAllRecipes();
      setState(() {
        _recipes = recipes;
        _loading = false;
      });
      widget.onRecipesLoaded?.call();
    } catch (e) {
      // print("❌ Failed to fetch recipes: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  void refresh() {
    setState(() => _loading = true);
    _loadRecipes();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_recipes.isEmpty) return const Text("Your Recipes will appear here...");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0), // remove side gap
      child: ListView.builder(
        padding: EdgeInsets.zero, 
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final recipe = _recipes[index];
          final categoriesStyle = _getToneStyle(recipe.categories);
          // final formattedDate = DateFormat('EEE, MMM d, y').format(recipe.createdAt.toLocal());

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoriesStyle.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // if (recipe.imageFile != null && recipe.imageFile!.isNotEmpty)
                  //   ClipRRect(
                  //     borderRadius: BorderRadius.circular(4),
                  //       child: RecipeImage(
                  //         recipeId: recipe.id,
                  //         url: recipe.imageFile!,
                  //         kind: RecipeImageKind.tile,
                  //         width: 48,
                  //         height: 48,
                  //         fit: BoxFit.cover,
                  //       ),
                      // child: Image.network(
                      //   recipe.imageFile!,
                      //   width: 48,
                      //   height: 48,
                      //   fit: BoxFit.cover,
                      // ),
                    // ),
                  const SizedBox(width: 6),
                  // Date and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   formattedDate,
                        //   style: TextStyle(fontSize: 12, color: categoriesStyle.text),
                        // ),
                        Text(
                          recipe.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: categoriesStyle.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      recipe.archived ? Icons.visibility_off : Icons.visibility,
                      // color: const Color.fromARGB(255, 255, 255, 255),
                      color: categoriesStyle.text,
                    ),
                    onPressed: () async {
                      try {
                        final newHidden = await ApiService.toggleHiddenRecipe(recipe.id);

                        setState(() {
                          _recipes = _recipes.map((d) {
                            return d.id == recipe.id
                                ? d.copyWith(archived: newHidden)
                                : d;
                          }).toList();
                        });
                      } catch (e) {
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('❌ Failed to update recipe visibility')),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    // icon: const Icon(Icons.delete, color: Color.fromARGB(255, 0, 0, 0)),
                    icon: Icon(Icons.delete, color: categoriesStyle.text),
                    color: categoriesStyle.text,
                    tooltip: "Delete",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Recipe'),
                          content: const Text('Are you sure you want to delete this recipe?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await ApiService.deleteRecipe(recipe.id);

                          if (!mounted) return; // check after the await
                          final messenger = ScaffoldMessenger.of(context); // capture after await

                          setState(() {
                            _recipes.removeWhere((d) => d.id == recipe.id);
                          });

                          messenger.showSnackBar(
                            const SnackBar(content: Text('🗑️ Recipe deleted')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context); // capture after await
                          messenger.showSnackBar(
                            const SnackBar(content: Text('❌ Failed to delete recipe')),
                          );
                        }
                      }
                    }
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
