import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final p = join(await getDatabasesPath(), 'job_offer_us.db');
    return openDatabase(
      p,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE history ADD COLUMN signing_bonus REAL NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE history ADD COLUMN comparison_json TEXT');
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_title TEXT NOT NULL,
        company TEXT NOT NULL,
        location TEXT NOT NULL,
        salary REAL NOT NULL,
        bonus REAL NOT NULL DEFAULT 0,
        benefits REAL NOT NULL DEFAULT 0,
        stock_options REAL NOT NULL DEFAULT 0,
        relocation REAL NOT NULL DEFAULT 0,
        pto INTEGER NOT NULL DEFAULT 0,
        signing_bonus REAL NOT NULL DEFAULT 0,
        net_salary REAL NOT NULL,
        monthly_net REAL NOT NULL,
        tax_rate REAL NOT NULL,
        created_at TEXT NOT NULL,
        comparison_json TEXT
      )
    ''');
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
