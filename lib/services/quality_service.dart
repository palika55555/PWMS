import '../database/database_helper.dart';
import '../models/quality_check.dart';

class QualityService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Pridanie kontroly kvality
  Future<int> addQualityCheck(QualityCheck check) async {
    final db = await _db.database;
    return await db.insert('quality_checks', check.toMap());
  }

  // Získanie všetkých kontrol kvality pre šaržu
  Future<List<QualityCheck>> getQualityChecksForBatch(int batchId) async {
    final db = await _db.database;
    final maps = await db.query(
      'quality_checks',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'checked_date DESC',
    );

    return List.generate(maps.length, (i) => QualityCheck.fromMap(maps[i]));
  }

  // Aktualizácia stavu kvality šarže
  Future<int> updateBatchQualityStatus(int batchId, String status, {String? notes}) async {
    final db = await _db.database;
    return await db.update(
      'production_batches',
      {
        'quality_status': status,
        'quality_notes': notes,
      },
      where: 'id = ?',
      whereArgs: [batchId],
    );
  }

  // Získanie štatistiky kvality
  Future<Map<String, int>> getQualityStatistics() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT quality_status, COUNT(*) as count
      FROM production_batches
      GROUP BY quality_status
    ''');

    final stats = <String, int>{};
    for (var map in maps) {
      stats[map['quality_status'] as String] = map['count'] as int;
    }

    return stats;
  }
}

