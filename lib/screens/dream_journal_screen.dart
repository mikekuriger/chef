// screens/dream_journal_screen.dart
// ignore_for_file: unused_field

import 'package:chef/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chef/widgets/dream_journal_widget.dart';
import 'package:chef/constants.dart';
import 'package:chef/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:chef/models/dream.dart';
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
  Map<String, int> _categoryCounts = {};

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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _showCalendar = false; // Collapsed by default
  Map<DateTime, List<Recipe>> _recipesByDate = {};
  
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
    final recipes = _journalKey.currentState?.getRecipes() ?? [];

    setState(() {
      _recipeCount = recipes.length;

      final categoryMap = <String, int>{};

      for (final r in recipes) {
        final raw = (r.categories ?? '').trim();
        if (raw.isEmpty) continue;

        // Split comma-separated list into individual categories
        final parts = raw
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty);

        // Optional: de-dupe categories within the same recipe
        final unique = parts.toSet();

        for (final cat in unique) {
          categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        }
      }

      _categoryCounts = categoryMap;

      final mostCommon = categoryMap.entries.fold<MapEntry<String, int>?>(null, (prev, entry) {
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
      final status = await ApiService.getSubscriptionStatus();

      setState(() {
        _isPro = status.isActive;
        _textRemainingWeek = status.textRemainingWeek;            // null for paid
        _imageRemainingLifetime = status.imageRemainingLifetime;  // null for paid
        _nextReset = status.nextReset;                            // null for paid
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

  // Get filtered recipes for the selected date
  List<Recipe> getFilteredRecipes() {
    final allRecipes = _journalKey.currentState?.getRecipes() ?? [];
    
    if (_selectedDay == null) {
      return allRecipes; // Return all recipes if no date is selected
    }
    
    // Filter recipes for the selected day
    return allRecipes.where((recipe) {
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
  
  // Generate a consistent color for each mood
  Color _getMoodColor(String mood) {
    // App's predefined moods with their colors
    // Using text colors for dark backgrounds to ensure visibility
    final Map<String, Color> predefinedMoods = {
      'peaceful / gentle': Colors.blue.shade100,
      'epic / heroic': Colors.orange.shade100,
      'whimsical / surreal': Colors.purple.shade100,
      'nightmarish / dark': Colors.orange.shade200,
      'romantic / nostalgic': Colors.pink.shade100,
      'ancient / mythic': Colors.brown.shade100,
      'futuristic / uncanny': Colors.teal.shade100,
      'elegant / ornate': Colors.indigo.shade100,
    };
    
    // Normalize the mood string for comparison
    final normalizedMood = mood.toLowerCase().trim();
    
    // Check for exact matches first
    if (predefinedMoods.containsKey(normalizedMood)) {
      return predefinedMoods[normalizedMood]!;
    }
    
    // Check for partial matches (e.g., if mood contains "peaceful" or "gentle")
    for (final entry in predefinedMoods.entries) {
      final keywords = entry.key.split('/').map((k) => k.trim().toLowerCase());
      if (keywords.any((keyword) => normalizedMood.contains(keyword))) {
        return entry.value;
      }
    }
    
    // Otherwise generate a color based on the mood string
    // Use a simple hash function to ensure the same mood always gets the same color
    int hash = 0;
    for (int i = 0; i < mood.length; i++) {
      hash = mood.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    // Use the hash to generate a hue value between 0 and 360
    final hue = (hash % 360).abs().toDouble();
    
    // Create a color with the hue and fixed saturation/brightness
    // Using HSV color model for more vibrant colors
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
  }
  
  // Build sorted mood bars
  List<Widget> _buildSortedMoodBars() {
    if (_categoryCounts.isEmpty) {
      return [const Text('No recipe data available', style: TextStyle(color: Colors.white70))];
    }
    
    // Sort entries by count (descending)
    final sortedEntries = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Create a list of mood bar widgets
    return sortedEntries.map((entry) {
      // Calculate percentage for the progress bar
      final percentage = _recipeCount > 0 
          ? entry.value / _recipeCount 
          : 0.0;
      
      // Generate a color based on the mood name
      final color = _getMoodColor(entry.key);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Mood name
            Text(
              entry.key,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 8),
            // Progress bar
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Count only (no percentage)
            Text(
              "${entry.value}",
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Build compact calendar
  Widget _buildCalendar() {
    // Get current month info
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    // Calculate days from previous month to show
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday, 1 = Monday, etc.
    
    // Generate dates for the grid
    final List<DateTime> calendarDates = [];
    
    // Add days from previous month
    for (var i = 0; i < firstWeekday; i++) {
      calendarDates.add(firstDayOfMonth.subtract(Duration(days: firstWeekday - i)));
    }
    
    // Add days from current month
    for (var i = 1; i <= lastDayOfMonth.day; i++) {
      calendarDates.add(DateTime(_focusedDay.year, _focusedDay.month, i));
    }
    
    // Add days from next month to complete the grid (to multiple of 7)
    final remainingDays = 7 - (calendarDates.length % 7);
    if (remainingDays < 7) {
      for (var i = 1; i <= remainingDays; i++) {
        calendarDates.add(DateTime(_focusedDay.year, _focusedDay.month + 1, i));
      }
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with month name and navigation buttons - more compact
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 18,
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                });
              },
            ),
            Text(
              DateFormat.yMMM().format(_focusedDay), // Shorter month format
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 18,
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                });
              },
            ),
          ],
        ),
        
        // Days of week headers - more compact
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text('S', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('M', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('T', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('W', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('T', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('F', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('S', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        
        // Calendar grid - more compact
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            mainAxisExtent: 28, // Fixed smaller height
          ),
          itemCount: calendarDates.length,
          itemBuilder: (context, index) {
            final date = calendarDates[index];
            final isThisMonth = date.month == _focusedDay.month;
            final isToday = isSameDay(date, DateTime.now());
            final isSelected = isSameDay(date, _selectedDay);
            final hasRecipes = hasRecipesOnDay(date);
            final recipeCount = recipeCountForDay(date);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Toggle selection if the same day is tapped
                  if (isSameDay(date, _selectedDay)) {
                    _selectedDay = null;
                  } else {
                    _selectedDay = date;
                  }
                  // Force refresh the recipe list when a date is selected
                  _journalKey.currentState?.refresh();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.deepPurple 
                    : isToday 
                      ? Colors.deepPurple.shade100.withValues(alpha: 0.3) 
                      : null,
                  borderRadius: BorderRadius.circular(4), // Smaller radius
                  border: hasRecipes 
                    ? Border.all(color: Colors.deepPurple.shade300, width: 1) // Thinner border
                    : null,
                ),
                child: Stack(
                  children: [
                    // Day number
                    Center(
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 12, // Smaller font
                          color: isThisMonth 
                            ? isSelected 
                              ? Colors.white 
                              : [DateTime.saturday, DateTime.sunday].contains(date.weekday) 
                                ? Colors.grey.shade400 
                                : Colors.white
                            : Colors.grey.shade700,
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    
                    // Recipe indicators - more compact
                    if (hasRecipes)
                      Positioned(
                        bottom: 2, // Move up slightly
                        right: 0,
                        left: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                for (var i = 0; i < (recipeCount < 3 ? recipeCount : 3); i++)
                              Container(
                                width: 4, // Smaller dots
                                height: 4, // Smaller dots
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade300,
                                  shape: BoxShape.circle,
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                              ),
                            if (recipeCount > 3)
                              Text(
                                '+${recipeCount - 3}',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade200,
                                  fontSize: 6, // Smaller text
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
                              
                              if (_categoryCounts.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                // const Text(
                                //   "All Moods:",
                                //   style: TextStyle(
                                //     color: Colors.white,
                                //     fontWeight: FontWeight.bold,
                                //   ),
                                // ),
                                Row(
                                  children: [
                                    const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
                                    const SizedBox(width: 8),
                                    const Text('✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
                                  ],
                                ),
                                // const Divider(
                                //   height: 24,                  // vertical space
                                //   thickness: 1,
                                //   color: Colors.white24,       // subtle on dark bg
                                // ),
                                // const SizedBox(height: 8),
                                
                                // Progress bars for each mood - more compact layout and sorted by count
                                ..._buildSortedMoodBars(),
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
                  filteredRecipes: _selectedDay != null ? filteredRecipes : null,
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