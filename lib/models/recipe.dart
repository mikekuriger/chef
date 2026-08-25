// models/recipe.dart
import 'dart:convert';
import 'package:chef/constants.dart';

/// One structured ingredient line: {quantity, unit, name}.
/// `quantity` is kept as the original text (e.g. "1/2", "1 1/2", "2") so it
/// can be displayed as typed; scaling parses it to a double on demand.
class RecipeIngredient {
  final String? quantity;
  final String? unit;
  final String name;

  const RecipeIngredient({this.quantity, this.unit, required this.name});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      quantity: (json['quantity'] as String?)?.trim().isEmpty == true
          ? null
          : json['quantity'] as String?,
      unit: (json['unit'] as String?)?.trim().isEmpty == true
          ? null
          : json['unit'] as String?,
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        'unit': unit,
        'name': name,
      };

  RecipeIngredient copyWith({String? quantity, String? unit, String? name}) {
    return RecipeIngredient(
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      name: name ?? this.name,
    );
  }

  /// Best-effort parse of `quantity` to a double for scaling.
  /// Supports plain integers/decimals, simple fractions ("1/2"), and
  /// mixed numbers ("1 1/2"). Returns null if it can't confidently parse
  /// (e.g. "to taste") — that line just won't scale.
  double? get quantityAsDouble {
    final q = quantity?.trim();
    if (q == null || q.isEmpty) return null;

    final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(q);
    if (mixed != null) {
      final whole = double.parse(mixed.group(1)!);
      final num = double.parse(mixed.group(2)!);
      final den = double.parse(mixed.group(3)!);
      return den == 0 ? null : whole + (num / den);
    }

    final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(q);
    if (frac != null) {
      final num = double.parse(frac.group(1)!);
      final den = double.parse(frac.group(2)!);
      return den == 0 ? null : num / den;
    }

    return double.tryParse(q);
  }
}

class Recipe {
  final int id;
  final int userId;
  final String text;
  final String aiResponse;
  final String title;
  final String description;
  final String categories;
  final String? course;
  final String? mainIngredient;
  final String tags;
  final String time;
  final String servings;
  final int? baseServings;
  final String ingredients;
  final List<RecipeIngredient> ingredientsStructured;
  final String instructions;
  final String notes;
  final String variations;
  final String difficulty;
  final bool archived;
  final DateTime createdAt;
  final String? imageFile;

  Recipe({
    required this.id,
    required this.userId,
    required this.text,
    required this.aiResponse,
    required this.title,
    required this.description,
    required this.categories,
    this.course,
    this.mainIngredient,
    required this.tags,
    required this.time,
    required this.servings,
    this.baseServings,
    required this.ingredients,
    this.ingredientsStructured = const [],
    required this.instructions,
    required this.notes,
    required this.variations,
    required this.difficulty,
    required this.archived,
    required this.createdAt,
    this.imageFile,
  });

  /// True once this recipe has structured ingredients + a base serving count,
  /// i.e. it supports the serving-size scaler and row-level ingredient editing.
  bool get isStructured => ingredientsStructured.isNotEmpty && baseServings != null && baseServings! > 0;

  Recipe copyWith({
    int? id,
    int? userId,
    String? text,
    String? aiResponse,
    String? title,
    String? description,
    String? categories,
    String? course,
    String? mainIngredient,
    String? tags,
    String? time,
    String? servings,
    int? baseServings,
    String? ingredients,
    List<RecipeIngredient>? ingredientsStructured,
    String? instructions,
    String? notes,
    String? variations,
    String? difficulty,
    bool? archived,
    DateTime? createdAt,
    String? imageFile,
  }) {
    return Recipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      aiResponse: aiResponse ?? this.aiResponse,
      title: title ?? this.title,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      course: course ?? this.course,
      mainIngredient: mainIngredient ?? this.mainIngredient,
      tags: tags ?? this.tags,
      time: time ?? this.time,
      servings: servings ?? this.servings,
      baseServings: baseServings ?? this.baseServings,
      ingredients: ingredients ?? this.ingredients,
      ingredientsStructured: ingredientsStructured ?? this.ingredientsStructured,
      instructions: instructions ?? this.instructions,
      notes: notes ?? this.notes,
      variations: variations ?? this.variations,
      difficulty: difficulty ?? this.difficulty,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      imageFile: imageFile ?? this.imageFile,
    );
  }

  static List<RecipeIngredient> _parseIngredientsJson(dynamic raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String?;
    final createdAt = (createdAtStr != null && createdAtStr.isNotEmpty)
        ? DateTime.parse(createdAtStr)
        : DateTime.now();

    final rawImage = json['image_file'] as String?;
    final imageFile = (rawImage != null && rawImage.isNotEmpty)
        ? '${AppConfig.baseUrl}$rawImage'
        : null;

    final rawBaseServings = json['base_servings'];
    final baseServings = rawBaseServings is int
        ? rawBaseServings
        : int.tryParse(rawBaseServings?.toString() ?? '');

    return Recipe(
      id: json['id'] ?? json['recipe_id'] ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      text: (json['text'] as String?) ?? '',
      aiResponse: (json['ai_response'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      categories: (json['categories'] as String?)?.trim() ?? '',
      course: (json['course'] as String?)?.trim().isEmpty == true ? null : (json['course'] as String?)?.trim(),
      mainIngredient: (json['main_ingredient'] as String?)?.trim().isEmpty == true
          ? null
          : (json['main_ingredient'] as String?)?.trim(),
      tags: (json['tags'] as String?)?.trim() ?? '',
      time: (json['time'] as String?)?.trim() ?? '',
      servings: (json['servings'] as String?)?.trim() ?? '',
      baseServings: baseServings,
      ingredients: (json['ingredients'] as String?) ?? '',
      ingredientsStructured: _parseIngredientsJson(json['ingredients_json']),
      instructions: (json['instructions'] as String?) ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
      variations: (json['variations'] as String?) ?? '',
      difficulty: (json['difficulty'] as String?)?.trim() ?? '',
      archived: json['archived'] ?? false,
      createdAt: createdAt,
      imageFile: imageFile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'text': text,
      'ai_response': aiResponse,
      'title': title,
      'description': description,
      'categories': categories,
      'course': course,
      'main_ingredient': mainIngredient,
      'tags': tags,
      'time': time,
      'servings': servings,
      'base_servings': baseServings,
      'ingredients': ingredients,
      'ingredients_json': jsonEncode(ingredientsStructured.map((i) => i.toJson()).toList()),
      'instructions': instructions,
      'notes': notes,
      'variations': variations,
      'difficulty': difficulty,
      'archived': archived,
      'created_at': createdAt.toIso8601String(),
      'image_file': imageFile,
    };
  }
}

class User {
  String email;
  String? firstName;
  String? lastName;

  User({
    required this.email,
    this.firstName,
    this.lastName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}