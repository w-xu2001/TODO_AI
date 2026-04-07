import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/todo_item.dart';

class TodoLocalDataSource {
  static const _dbName = 'todo_ai.db';
  static const _dbVersion = 3;
  static const _tableName = 'todos';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) {
      return _database!;
    }

    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT NOT NULL,
            due_at TEXT NOT NULL,
            is_done INTEGER NOT NULL,
            source TEXT NOT NULL,
            color_value INTEGER NOT NULL DEFAULT 4280123322,
            progress INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            delete_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4280123322',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN progress INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN delete_at TEXT');
        }
      },
    );

    return _database!;
  }

  Future<List<TodoItem>> getTodos() async {
    final db = await _db();
    final rows = await db.query(
      _tableName,
      orderBy: 'due_at ASC, created_at ASC',
    );
    return rows.map(TodoItem.fromMap).toList();
  }

  Future<List<TodoItem>> getPendingDeletionTodos() async {
    final db = await _db();
    final rows = await db.query(
      _tableName,
      where: 'delete_at IS NOT NULL',
      orderBy: 'delete_at ASC',
    );
    return rows.map(TodoItem.fromMap).toList();
  }

  Future<TodoItem> insertTodo(TodoItem todo) async {
    final db = await _db();
    final id = await db.insert(_tableName, todo.toMap()..remove('id'));
    return todo.copyWith(id: id);
  }

  Future<void> updateTodo(TodoItem todo) async {
    final db = await _db();
    await db.update(
      _tableName,
      todo.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<void> deleteTodo(int id) async {
    final db = await _db();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTodosByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _db();
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    await db.delete(_tableName, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
