import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/saved_spot_service.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final p = join(await getDatabasesPath(), 'park_smart.db');
    return openDatabase(
      p,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location TEXT NOT NULL,
        hourly_rate REAL NOT NULL,
        hours_parked INTEGER NOT NULL,
        total_cost REAL NOT NULL,
        daily_budget REAL NOT NULL DEFAULT 0,
        monthly_savings REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await SavedSpotService.ensureTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await SavedSpotService.ensureTable(db);
    }
  }

  Future<void> insertHistory(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('history', row);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await database;
    return db.query('history', orderBy: 'created_at DESC');
  }

  Future<int> countHistory() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteHistory(int id) async {
    final db = await database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  Future<Map<String, dynamic>?> getHistoryById(int id) async {
    final db = await database;
    final result = await db.query('history', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }
}
