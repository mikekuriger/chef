// constants.dart
import 'package:flutter/material.dart';

final ValueNotifier<bool> recipeDataChanged = ValueNotifier(false);

// temporary page refreshing to test
final ValueNotifier<int> journalRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> galleryRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> profileRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> recipeEntryRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> editorRefreshTrigger = ValueNotifier(0);

const kWebClientId = '846080686597-bap701fbin0efm6m7lfcg3nhtc62nd6u.apps.googleusercontent.com';

class AppConfig {
  static const String baseUrl = 'https://chef-us-west-01.zentha.me';
}

// Fixed recipe taxonomy — keep in sync with chef-backend/prompts.py
// (RECIPE_COURSES / RECIPE_MAIN_INGREDIENTS) and chef-backend/app.py.
const List<String> kRecipeCourses = [
  'Breakfast', 'Lunch', 'Dinner', 'Appetizer', 'Side Dish',
  'Soup', 'Salad', 'Dessert', 'Snack', 'Drink', 'Sauce/Condiment',
];

const List<String> kRecipeMainIngredients = [
  'Chicken', 'Beef', 'Pork', 'Seafood', 'Egg',
  'Pasta/Grain', 'Vegetarian', 'Vegan', 'Other',
];

const String kUncategorizedLabel = 'Uncategorized';
