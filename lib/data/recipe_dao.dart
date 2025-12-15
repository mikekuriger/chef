// data/recipe_dao.dart
import 'dart:async';
import 'package:chef/models/recipe.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class RecipeDao {
  static final RecipeDao _instance = RecipeDao._internal();
  factory RecipeDao() => _instance;
  RecipeDao._internal();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'chef.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE recipes (
            id INTEGER PRIMARY KEY,
            user_id INTEGER,
            text TEXT,
            ai_response TEXT,
            title TEXT,
            description TEXT,
            categories TEXT,
            tags TEXT,
            time TEXT,
            servings TEXT,
            ingredients TEXT,
            instructions TEXT,
            notes TEXT,
            variations TEXT,
            difficulty TEXT,
            archived INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            image_file TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_recipes_created_at ON recipes(created_at DESC)'
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_recipes_archived ON recipes(archived)'
        );
      },
    );
    return _db!;
  }

  Map<String, Object?> _toMap(Recipe r) => {
        'id': r.id,
        'user_id': r.userId,
        'text': r.text,
        'ai_response': r.aiResponse,
        'title': r.title,
        'description': r.description,
        'categories': r.categories,
        'tags': r.tags,
        'time': r.time,
        'servings': r.servings,
        'ingredients': r.ingredients,
        'instructions': r.instructions,
        'notes': r.notes,
        'variations': r.variations,
        'difficulty': r.difficulty,
        'archived': r.archived ? 1 : 0,
        'created_at': r.createdAt.toIso8601String(),
        'image_file': r.imageFile,
      };

  Recipe _fromMap(Map<String, Object?> m) {
    return Recipe(
      id: (m['id'] as num).toInt(),
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      text: (m['text'] as String?) ?? '',
      aiResponse: (m['ai_response'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      categories: (m['categories'] as String?) ?? '',
      tags: (m['tags'] as String?) ?? '',
      time: (m['time'] as String?) ?? '',
      servings: (m['servings'] as String?) ?? '',
      ingredients: (m['ingredients'] as String?) ?? '',
      instructions: (m['instructions'] as String?) ?? '',
      notes: (m['notes'] as String?) ?? '',
      variations: (m['variations'] as String?) ?? '',
      difficulty: (m['difficulty'] as String?) ?? '',
      archived: (m['archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(m['created_at'] as String),
      imageFile: m['image_file'] as String?,
    );
  }

  Future<void> upsertMany(List<Recipe> recipes) async {
    final db = await _open();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in recipes) {
        batch.insert(
          'recipes',
          _toMap(r),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsert(Recipe r) async {
    final db = await _open();
    await db.insert(
      'recipes',
      _toMap(r),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Recipe>> getAll({bool includeArchived = false}) async {
    final db = await _open();
    final rows = await db.query(
      'recipes',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromMap).toList();
  }
}