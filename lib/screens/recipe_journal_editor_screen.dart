// screens/recipe_journal_editor_screen.dart
import 'package:chef/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:chef/widgets/recipe_journal_editor_widget.dart';
import 'package:chef/constants.dart';

class RecipeJournalEditorScreen extends StatefulWidget {
  final ValueNotifier<int> refreshTrigger;
  const RecipeJournalEditorScreen({super.key, required this.refreshTrigger});

  @override
  State<RecipeJournalEditorScreen> createState() => _RecipeJournalEditorScreenState();
}

class _RecipeJournalEditorScreenState extends State<RecipeJournalEditorScreen> {
  bool _expanded = false;
  @override
  void initState() {
    super.initState();

    // ✅ Listen for bottom nav tab refresh
    widget.refreshTrigger.addListener(_refreshJournal);

    // Refresh journal if a new recipe was added
    recipeDataChanged.addListener(() {
      if (recipeDataChanged.value == true) {
        _refreshJournal();
        recipeDataChanged.value = false;
      }
    });
  }

  final GlobalKey<RecipeJournalEditorWidgetState> _journalKey = GlobalKey();
  
  void _refreshJournal() {
    _journalKey.currentState?.refresh();

    // 👇 collapse help box whenever this screen is triggered to refresh
      setState(() {
      _expanded = false;
    });
  }
  
  @override
  void dispose() {
    widget.refreshTrigger.removeListener(_refreshJournal);
    recipeDataChanged.removeListener(_refreshJournal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshJournal();
      },
      child: SingleChildScrollView(
        // controller: _scrollController,
        padding: const EdgeInsets.all(4),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.purple600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hide / Delete Recipes',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white, // ✅ make icon white
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: _expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "Tap the eye icon to hide/unhide a recipe.\n"
                            "Tap the trash icon to delete permanently.\n"
                            "Deleted items can’t be recovered.",
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),

                ),
              ),
            ),
            RecipeJournalEditorWidget(
              key: _journalKey,
            ),
          ],
        ),
      ),
    );
  }
}
