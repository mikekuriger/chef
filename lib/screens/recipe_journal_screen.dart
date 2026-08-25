// screens/recipe_journal_screen.dart
// ignore_for_file: unused_field

import 'package:chef/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chef/widgets/recipe_journal_widget.dart';
import 'package:chef/constants.dart';
import 'package:chef/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/theme/colors.dart';

// Custom enum to replace missing CalendarFormat
enum CalendarFormat { month, week }

class RecipeJournalScreen extends StatefulWidget {
  final ValueNotifier<int> refreshTrigger;
  const RecipeJournalScreen({super.key, required this.refreshTrigger});

  @override
  State<RecipeJournalScreen> createState() => _RecipeJournalScreenState();
}

class _RecipeJournalScreenState extends State<RecipeJournalScreen> {
  bool _statsExpanded = false;
  Map<String, int> _courseCounts = {};
  Map<String, int> _mainIngredientCounts = {};

  // state fields
  int _recipeCount = 0;
  String _mostCommonCategory = '';
  // int _longestWordCount = 0;

  int? _textRemainingWeek;
  int? _imageRemainingLifetime;
  DateTime? _nextReset;
  bool _quotaLoading = false;
  String? _quotaError;
  bool? _isPro; // null = loading
  
  // Calendar state
  final DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  // bool _showCalendar = false; // Collapsed by default
  Map<DateTime, List<Recipe>> _recipesByDate = {};
  
  // Category filtering state (fixed taxonomy: Course + Main Ingredient)
  final Set<String> _selectedCourses = {};
  final Set<String> _selectedMainIngredients = {};
  
  // Visibility preferences
  bool _showStatsSection = true; // Controls if stats section is shown at all
  bool _showCalendarSection = false; // Controls if calendar section is shown at all


  // Load visibility preferences from SharedPreferences
  Future<void> _loadVisibilityPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showStatsSection = prefs.getBool('show_recipe_stats') ?? true;
        _showCalendarSection = prefs.getBool('show_recipe_calendar') ?? false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load visibility preferences: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Load visibility preferences
    _loadVisibilityPreferences();

    // Initial load after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStats();
    });

    // ✅ Listen for bottom nav tab refresh
    widget.refreshTrigger.addListener(_refreshJournal);

    // Refresh journal if a new recipe was added
    recipeDataChanged.addListener(() {
      if (recipeDataChanged.value == true) {
        _refreshJournal();
        _refreshStats();
        // _loadStats();
        // await _loadQuota();
        recipeDataChanged.value = false;
      }
    });
  }

  final GlobalKey<RecipeJournalWidgetState> _journalKey = GlobalKey();

  void _refreshJournal() {
    _journalKey.currentState?.refresh();

    // 👇 collapse stats box whenever this screen is triggered to refresh
    setState(() {
      _statsExpanded = false;
    });
  }

  void _loadStats() {
    final recipes = _journalKey.currentState?.getAllRecipes() ?? [];

    setState(() {
      _recipeCount = recipes.length;

      final courseMap = <String, int>{};
      final mainIngredientMap = <String, int>{};

      for (final r in recipes) {
        final course = r.course?.trim();
        final courseKey = (course == null || course.isEmpty) ? kUncategorizedLabel : course;
        courseMap[courseKey] = (courseMap[courseKey] ?? 0) + 1;

        final rawMain = r.mainIngredient?.trim();
        if (rawMain == null || rawMain.isEmpty) continue;
        // main_ingredient can be a comma-joined "Chicken, Pasta/Grain"
        final unique = rawMain
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        for (final m in unique) {
          mainIngredientMap[m] = (mainIngredientMap[m] ?? 0) + 1;
        }
      }

      _courseCounts = courseMap;
      _mainIngredientCounts = mainIngredientMap;

      final mostCommon = courseMap.entries
          .where((e) => e.key != kUncategorizedLabel)
          .fold<MapEntry<String, int>?>(null, (prev, entry) {
        return (prev == null || entry.value > prev.value) ? entry : prev;
      });

      _mostCommonCategory = mostCommon?.key ?? 'N/A';
    });
  }


  Future<void> _loadQuota() async {
    setState(() {
      _quotaLoading = true;
      _quotaError = null;
    });

    try {
      // final status = await ApiService.getSubscriptionStatus();

      setState(() {
        _isPro = true;
        // _isPro = status.isActive;
        // _textRemainingWeek = status.textRemainingWeek;            // null for paid
        // _imageRemainingLifetime = status.imageRemainingLifetime;  // null for paid
        // _nextReset = status.nextReset;                            // null for paid
        _quotaLoading = false;
      });
    } catch (e) {
      setState(() {
        _quotaLoading = false;
        _quotaError = 'Failed to load quota';
      });
    }
  }

  // Organize recipes by date for calendar
  void _organizeRecipesByDate() {
    final recipes = _journalKey.currentState?.getRecipes() ?? [];
    final Map<DateTime, List<Recipe>> recipesByDate = {};

    for (final recipe in recipes) {
      // Create date key with just year, month, day (no time)
      final date = DateTime(
        recipe.createdAt.year,
        recipe.createdAt.month,
        recipe.createdAt.day,
      );

      if (recipesByDate[date] == null) {
        recipesByDate[date] = [];
      }
      recipesByDate[date]!.add(recipe);
    }

    setState(() {
      _recipesByDate = recipesByDate;
    });
  }

  Future<void> _refreshStats() async {
    _loadStats();          // local aggregates
    await _loadQuota();    // network
    _organizeRecipesByDate(); // For calendar
  }

  // Helper for calendar - check if two dates are the same day
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Get filtered recipes for the selected date and categories
  List<Recipe> getFilteredRecipes() {
    final allRecipes = _journalKey.currentState?.getAllRecipes() ?? [];
    
    // If no recipes loaded yet, return empty (don't filter)
    if (allRecipes.isEmpty) return [];
    
    // First filter by date if selected
    List<Recipe> dateFiltered = allRecipes;
    if (_selectedDay != null) {
      dateFiltered = allRecipes.where((recipe) {
        final recipeDate = DateTime(
          recipe.createdAt.year, 
          recipe.createdAt.month, 
          recipe.createdAt.day
        );
        
        final selectedDate = DateTime(
          _selectedDay!.year, 
          _selectedDay!.month, 
          _selectedDay!.day
        );
        
        return recipeDate.isAtSameMomentAs(selectedDate);
      }).toList();
    }
    
    // Then filter by selected Course chips (recipes with no course fall
    // under the "Uncategorized" chip)
    if (_selectedCourses.isNotEmpty) {
      dateFiltered = dateFiltered.where((recipe) {
        final course = recipe.course?.trim();
        final courseKey = (course == null || course.isEmpty) ? kUncategorizedLabel : course;
        return _selectedCourses.contains(courseKey);
      }).toList();
    }

    // Then filter by selected Main Ingredient chips
    if (_selectedMainIngredients.isNotEmpty) {
      dateFiltered = dateFiltered.where((recipe) {
        final raw = recipe.mainIngredient?.trim();
        if (raw == null || raw.isEmpty) return false;
        final recipeMainIngredients = raw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        return _selectedMainIngredients.any(recipeMainIngredients.contains);
      }).toList();
    }

    return dateFiltered;
  }

  // Check if a specific day has recipes
  bool hasRecipesOnDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _recipesByDate.containsKey(normalizedDay) && 
           _recipesByDate[normalizedDay]!.isNotEmpty;
  }

  // Get number of recipes for a specific day
  int recipeCountForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _recipesByDate[normalizedDay]?.length ?? 0;
  }
  
  // Generate a consistent color for each fixed-taxonomy category label
  Color _getCategoryColor(String category) {
    // Colors for the fixed Course / Main Ingredient taxonomy.
    // Using text colors for dark backgrounds to ensure visibility.
    final Map<String, Color> predefinedCategorys = {
      'breakfast': Colors.orange.shade200,
      'lunch': Colors.blue.shade200,
      'dinner': Colors.indigo.shade200,
      'appetizer': Colors.teal.shade200,
      'side dish': Colors.lime.shade200,
      'soup': Colors.brown.shade200,
      'salad': Colors.lightGreen.shade200,
      'dessert': Colors.pink.shade200,
      'snack': Colors.amber.shade200,
      'drink': Colors.cyan.shade200,
      'sauce/condiment': Colors.deepOrange.shade200,
      'chicken': Colors.yellow.shade200,
      'beef': Colors.red.shade300,
      'pork': Colors.pink.shade300,
      'seafood': Colors.lightBlue.shade200,
      'egg': Colors.amber.shade100,
      'pasta/grain': Colors.brown.shade100,
      'vegetarian': Colors.green.shade200,
      'vegan': Colors.green.shade300,
      'other': Colors.blueGrey.shade200,
      'uncategorized': Colors.grey.shade400,
    };

    final normalizedCategory = category.toLowerCase().trim();
    if (predefinedCategorys.containsKey(normalizedCategory)) {
      return predefinedCategorys[normalizedCategory]!;
    }

    // Fallback: generate a stable color from the string's hash so any
    // future taxonomy addition still gets a consistent color automatically.
    int hash = 0;
    for (int i = 0; i < category.length; i++) {
      hash = category.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash % 360).abs().toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
  }

  // Build a row of tappable category chips (e.g. Course, or Main Ingredient)
  // sorted by how many recipes use them. This replaces the old freeform
  // tag-cloud progress bars — a small, fixed set of buttons the user can
  // tap to browse (Dinner, Chicken, Seafood...) instead of scrolling a wall
  // of AI-invented tags.
  Widget _buildCategoryChipRow({
    required Map<String, int> counts,
    required Set<String> selected,
    required void Function(String) onToggle,
  }) {
    if (counts.isEmpty) {
      return const Text('No recipe data available', style: TextStyle(color: Colors.white70));
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedEntries.map((entry) {
        final color = _getCategoryColor(entry.key);
        final isSelected = selected.contains(entry.key);

        return GestureDetector(
          onTap: () => onToggle(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : Colors.white24,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${entry.value}',
                  style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    widget.refreshTrigger.removeListener(_refreshJournal);
    recipeDataChanged.removeListener(_refreshJournal);  // if you want to clean that too
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshJournal();
        // _loadStats();
        // await _loadQuota();
        _refreshStats();
        _loadVisibilityPreferences(); // Reload preferences
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(4),  // side spacing
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Stats section - only show if preference is enabled
            if (_showStatsSection)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),            // recipes logged/stats size
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _statsExpanded = !_statsExpanded;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12), // height of stat box
                  decoration: BoxDecoration(
                    // color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.4),
                    color: AppColors.black.withAlpha(200),                           // Credits Background
                    // color: AppColors.purple950, // Dark purple background
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color.fromARGB(255, 255, 230, 7),
                      // color: const Color.fromARGB(255, 170, 153, 1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 130, 217, 255).withValues(alpha: 0.5), // Shadow color with opacity
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // header row with title and arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           RichText(
                                text: TextSpan(
                                  children: [
                                    if (_isPro == null) ...[
                                      const TextSpan(text: " ", style: TextStyle(color: Colors.white)),
                                    ] else if (_isPro!) ...[
                                      const TextSpan(
                                        text: "✨ Recipes Logged: ",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                                      ),
                                      TextSpan(
                                        text: '$_recipeCount',
                                        style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                                      ),
                                    ] else ...[
                                      TextSpan(
                                        text: "✨ Recipe Credits: ",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                                      ),
                                      TextSpan(
                                        text: "${_textRemainingWeek ?? 0}",
                                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(
                                        text: "  🔮 Image Credits: ",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                                      ),
                                      TextSpan(
                                        text: "${_imageRemainingLifetime ?? 0}",
                                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          Icon(
                            _statsExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white, // ✅ white icon
                          ),
                        ],
                      ),

                      // expanding section
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: _statsExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                  // Show this for free accounts only (hide for pro)      
                              if (_isPro == false) ...[   
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: "Recipes Logged: ",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '$_recipeCount',
                                        style: const TextStyle(
                                          color: Colors.yellow,
                                          fontWeight: FontWeight.bold,
                                          // fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: "Most Common Category: ",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _mostCommonCategory,
                                      style: const TextStyle(
                                        color: Colors.yellow,
                                        fontWeight: FontWeight.bold,
                                        // fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (_courseCounts.isNotEmpty || _mainIngredientCounts.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
                                    const SizedBox(width: 8),
                                    const Text('✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
                                  ],
                                ),

                                // Course chips (Dinner, Breakfast, Dessert...) — tap to filter
                                if (_courseCounts.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Course', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  _buildCategoryChipRow(
                                    counts: _courseCounts,
                                    selected: _selectedCourses,
                                    onToggle: (key) => setState(() {
                                      if (!_selectedCourses.remove(key)) _selectedCourses.add(key);
                                    }),
                                  ),
                                ],

                                // Main Ingredient chips (Chicken, Seafood, Vegetarian...) — tap to filter
                                if (_mainIngredientCounts.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text('Main Ingredient', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  _buildCategoryChipRow(
                                    counts: _mainIngredientCounts,
                                    selected: _selectedMainIngredients,
                                    onToggle: (key) => setState(() {
                                      if (!_selectedMainIngredients.remove(key)) _selectedMainIngredients.add(key);
                                    }),
                                  ),
                                ],

                                // Clear filters button when categories are selected
                                if (_selectedCourses.isNotEmpty || _selectedMainIngredients.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: Text(
                                        "Clear Category Filters (${_selectedCourses.length + _selectedMainIngredients.length})",
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.yellow,
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedCourses.clear();
                                          _selectedMainIngredients.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],

                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text("Add a New Recipe"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.deepPurple.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MainScaffold(initialIndex: 0),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            

 // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4), // 8px above + 8px below
              child: Divider(
                color: Colors.yellow.withValues(alpha: 0.75),
                thickness: 1,
                indent: 16,
                endIndent: 16,
              ),
            ),


            // Recipe list with filtered recipes
            Builder(
              builder: (context) {
                final filteredRecipes = getFilteredRecipes();
                
                // Show message if no recipes match the selected date
                if (_selectedDay != null && filteredRecipes.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'No recipes recorded on ${DateFormat('EEE, MMM d, y').format(_selectedDay!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Date Filter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade300,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedDay = null;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }
                
                // Show recipe list with filtered recipes if available
                return RecipeJournalWidget(
                  key: _journalKey,
                  onRecipesLoaded: _refreshStats,
                  filteredRecipes: (_selectedDay != null || _selectedCourses.isNotEmpty || _selectedMainIngredients.isNotEmpty)
                      ? filteredRecipes
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function
int min(int a, int b) {
  return a < b ? a : b;
}