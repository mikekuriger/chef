// data/recipe_dao.dart
import 'dart:async';
import 'dart:convert';
import 'package:chef/models/recipe.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class RecipeDao {
  static final RecipeDao _instance = RecipeDao._internal();
  factory RecipeDao() => _instance;
  RecipeDao._internal();

  static const int _dbVersion = 4;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'chef.db');

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
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
            course TEXT,
            main_ingredient TEXT,
            tags TEXT,
            time TEXT,
            servings TEXT,
            base_servings INTEGER,
            ingredients TEXT,
            ingredients_json TEXT,
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

        // Pantry items ("My Pantry" feature)
        await db.execute('''
          CREATE TABLE pantry_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            location TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(user_id, normalized_name, location)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pantry_user_location_updated ON pantry_items(user_id, location, updated_at DESC)'
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Fresh upgrade path from v1 -> v3: create the v3 pantry table directly.
          await db.execute('''
            CREATE TABLE pantry_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              normalized_name TEXT NOT NULL,
              location TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE(user_id, normalized_name, location)
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pantry_user_location_updated ON pantry_items(user_id, location, updated_at DESC)'
          );
          return;
        }

        if (oldVersion < 3) {
          // v2 -> v3 migration: rebuild table to change UNIQUE constraint.
          await db.transaction((txn) async {
            await txn.execute('ALTER TABLE pantry_items RENAME TO pantry_items_old');
            await txn.execute('''
              CREATE TABLE pantry_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                normalized_name TEXT NOT NULL,
                location TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(user_id, normalized_name, location)
              )
            ''');
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_pantry_user_location_updated ON pantry_items(user_id, location, updated_at DESC)'
            );
            await txn.execute('''
              INSERT INTO pantry_items (
                id, user_id, name, normalized_name, location, created_at, updated_at
              )
              SELECT
                id, 0, name, normalized_name, location, created_at, updated_at
              FROM pantry_items_old
            ''');
            await txn.execute('DROP TABLE pantry_items_old');
          });
        }

        if (oldVersion < 4) {
          // v3 -> v4: add fixed-taxonomy + structured-ingredient columns to recipes.
          await db.execute('ALTER TABLE recipes ADD COLUMN course TEXT');
          await db.execute('ALTER TABLE recipes ADD COLUMN main_ingredient TEXT');
          await db.execute('ALTER TABLE recipes ADD COLUMN base_servings INTEGER');
          await db.execute('ALTER TABLE recipes ADD COLUMN ingredients_json TEXT');
        }
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
        'course': r.course,
        'main_ingredient': r.mainIngredient,
        'tags': r.tags,
        'time': r.time,
        'servings': r.servings,
        'ingredients': r.ingredients,
        'ingredients_json': jsonEncode(r.ingredientsStructured.map((i) => i.toJson()).toList()),
        'instructions': r.instructions,
        'notes': r.notes,
        'variations': r.variations,
        'difficulty': r.difficulty,
        'archived': r.archived ? 1 : 0,
        'created_at': r.createdAt.toIso8601String(),
        'image_file': r.imageFile,
      };

  List<RecipeIngredient> _parseIngredientsJsonColumn(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Recipe _fromMap(Map<String, Object?> m) {
    return Recipe(
      id: (m['id'] as num).toInt(),
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      text: (m['text'] as String?) ?? '',
      aiResponse: (m['ai_response'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      categories: (m['categories'] as String?) ?? '',
      course: m['course'] as String?,
      mainIngredient: m['main_ingredient'] as String?,
      tags: (m['tags'] as String?) ?? '',
      time: (m['time'] as String?) ?? '',
      servings: (m['servings'] as String?) ?? '',
      ingredients: (m['ingredients'] as String?) ?? '',
      ingredientsStructured: _parseIngredientsJsonColumn(m['ingredients_json'] as String?),
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