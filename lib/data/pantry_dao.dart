// data/pantry_dao.dart
import 'dart:async';

import 'package:chef/models/pantry_item.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class PantryDao {
  static final PantryDao _instance = PantryDao._internal();
  factory PantryDao() => _instance;
  PantryDao._internal();

  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'chef.db');

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, _) async {
        // NOTE: We create BOTH tables here so whichever DAO opens the DB first
        // establishes a complete schema on a fresh install.
        await _createRecipesTable(db);
        await _createPantryTableV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPantryTableV3(db);
          return;
        }

        if (oldVersion < 3) {
          // v2 -> v3 migration: rebuild table to change UNIQUE constraint.
          await db.transaction((txn) async {
            await txn.execute('ALTER TABLE pantry_items RENAME TO pantry_items_old');
            await _createPantryTableV3(txn);
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
      },
    );

    return _db!;
  }

  Future<void> _createPantryTableV3(DatabaseExecutor db) async {
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
      'CREATE INDEX IF NOT EXISTS idx_pantry_user_location_updated ON pantry_items(user_id, location, updated_at DESC)',
    );
  }

  Future<void> _createRecipesTable(Database db) async {
    // Keep schema in sync with RecipeDao.onCreate.
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
      'CREATE INDEX IF NOT EXISTS idx_recipes_created_at ON recipes(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recipes_archived ON recipes(archived)',
    );
  }

  Future<int> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId') ?? 0;
  }

  Future<List<PantryItem>> getAll({PantryLocation? location}) async {
    final db = await _open();

    final userId = await _currentUserId();

    // If this device had pantry data before per-user scoping existed (v2 -> v3
    // migration sets user_id=0), and the current user has no rows yet, adopt
    // those legacy rows.
    if (userId != 0) {
      final userCount = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM pantry_items WHERE user_id = ?',
              [userId],
            ),
          ) ??
          0;

      if (userCount == 0) {
        final legacyCount = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM pantry_items WHERE user_id = 0',
              ),
            ) ??
            0;

        if (legacyCount > 0) {
          await db.update(
            'pantry_items',
            {'user_id': userId},
            where: 'user_id = 0',
          );
        }
      }
    }

    final rows = await db.query(
      'pantry_items',
      where: location == null ? 'user_id = ?' : 'user_id = ? AND location = ?',
      whereArgs: location == null ? [userId] : [userId, location.dbValue],
      orderBy: 'updated_at DESC',
    );

    return rows.map(PantryItem.fromDb).toList();
  }

  Future<void> upsertMany({
    required PantryLocation location,
    required List<String> names,
  }) async {
    final db = await _open();

    final userId = await _currentUserId();

    final now = DateTime.now();

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final raw in names) {
        final name = raw.trim();
        if (name.isEmpty) continue;

        final normalized = PantryItem.normalize(name);

        batch.insert(
          'pantry_items',
          {
            'user_id': userId,
            'name': name,
            'normalized_name': normalized,
            'location': location.dbValue,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> rename({
    required int id,
    required String newName,
  }) async {
    final db = await _open();

    final name = newName.trim();
    if (name.isEmpty) return;

    await db.update(
      'pantry_items',
      {
        'name': name,
        'normalized_name': PantryItem.normalize(name),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> move({
    required int id,
    required PantryLocation newLocation,
  }) async {
    final db = await _open();

    final userId = await _currentUserId();

    // Fetch existing name so UNIQUE(normalized_name, location) is respected.
    final rows = await db.query(
      'pantry_items',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final name = (rows.first['name'] as String?) ?? '';
    if (name.trim().isEmpty) return;

    await db.insert(
      'pantry_items',
      {
        'user_id': userId,
        'name': name,
        'normalized_name': PantryItem.normalize(name),
        'location': newLocation.dbValue,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await delete(id);
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLocation(PantryLocation location) async {
    final db = await _open();

    final userId = await _currentUserId();
    await db.delete(
      'pantry_items',
      where: 'user_id = ? AND location = ?',
      whereArgs: [userId, location.dbValue],
    );
  }
}
