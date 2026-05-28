import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';

/// Emplacement de stationnement sauvegardé par l'utilisateur.
class SavedSpot {
  final int? id;
  final double latitude;
  final double longitude;
  final String label; // nom de rue ou adresse
  final String? notes;
  final String savedAt; // ISO 8601

  const SavedSpot({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.notes,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'notes': notes,
        'saved_at': savedAt,
      };

  factory SavedSpot.fromMap(Map<String, dynamic> m) => SavedSpot(
        id: m['id'] as int?,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        label: m['label'] as String,
        notes: m['notes'] as String?,
        savedAt: m['saved_at'] as String,
      );
}

/// Service de gestion des spots sauvegardés (SQLite).
///
/// Limite : 50 spots max (freemium — premium = illimité).
class SavedSpotService {
  SavedSpotService._();
  static final instance = SavedSpotService._();

  static const _table = 'saved_spots';
  static const _freemiumLimit = 50;

  // ── Schema ───────────────────────────────────────────────────────────────

  static Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude   REAL    NOT NULL,
        longitude  REAL    NOT NULL,
        label      TEXT    NOT NULL,
        notes      TEXT,
        saved_at   TEXT    NOT NULL
      )
    ''');
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<List<SavedSpot>> getAll() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(_table, orderBy: 'saved_at DESC');
      return rows.map(SavedSpot.fromMap).toList();
    } catch (e) {
      debugPrint('SavedSpotService.getAll: $e');
      return [];
    }
  }

  /// Retourne null si OK, ou un message d'erreur.
  Future<String?> save(SavedSpot spot) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_table'),
          ) ??
          0;
      if (count >= _freemiumLimit) {
        return 'Limite de $_freemiumLimit spots atteinte';
      }
      await db.insert(_table, spot.toMap());
      return null;
    } catch (e) {
      debugPrint('SavedSpotService.save: $e');
      return e.toString();
    }
  }

  Future<void> delete(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('SavedSpotService.delete: $e');
    }
  }

  Future<void> clear() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(_table);
    } catch (e) {
      debugPrint('SavedSpotService.clear: $e');
    }
  }

  /// Vérifie si un spot proche (< 30 m) est déjà sauvegardé.
  Future<bool> hasSimilar(double lat, double lon) async {
    final all = await getAll();
    for (final s in all) {
      final dlat = s.latitude - lat;
      final dlon = s.longitude - lon;
      // ~30 m = 0.00027°
      if (dlat * dlat + dlon * dlon < 7.29e-8) return true;
    }
    return false;
  }
}
