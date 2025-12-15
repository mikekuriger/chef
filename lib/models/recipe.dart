// models/recipe.dart
import 'package:chef/constants.dart';

class Recipe {
  final int id;
  final int userId;
  final String text;
  final String aiResponse;
  final String title;
  final String description;
  final String categories;
  final String tags;
  final String time;
  final String servings;
  final String ingredients;
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
    required this.tags,
    required this.time,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.notes,
    required this.variations,
    required this.difficulty,
    required this.archived,
    required this.createdAt,
    this.imageFile,
  });

  Recipe copyWith({
    int? id,
    int? userId,
    String? text,
    String? aiResponse,
    String? title,
    String? description,
    String? categories,
    String? tags,
    String? time,
    String? servings,
    String? ingredients,
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
      tags: tags ?? this.tags,
      time: time ?? this.time,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      notes: notes ?? this.notes,
      variations: variations ?? this.variations,
      difficulty: difficulty ?? this.difficulty,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      imageFile: imageFile ?? this.imageFile,
    );
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

    return Recipe(
      id: json['id'] ?? json['recipe_id'] ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      text: (json['text'] as String?) ?? '',
      aiResponse: (json['ai_response'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      categories: (json['categories'] as String?)?.trim() ?? '',
      tags: (json['tags'] as String?)?.trim() ?? '',
      time: (json['time'] as String?)?.trim() ?? '',
      servings: (json['servings'] as String?)?.trim() ?? '',
      ingredients: (json['ingredients'] as String?) ?? '',
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
      'tags': tags,
      'time': time,
      'servings': servings,
      'ingredients': ingredients,
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