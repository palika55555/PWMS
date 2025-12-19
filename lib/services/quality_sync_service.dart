import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/quality_check.dart';
import '../config/api_config.dart';

class QualitySyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static String get API_BASE_URL => ApiConfig.getQualityUrl();

  // Synchronizácia kvality z API do lokálnej databázy
  Future<void> syncQualityFromAPI(String batchNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL?batchNumber=$batchNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['quality'] != null) {
          final quality = data['quality'];
          final status = quality['status'] as String?;
          final notes = quality['notes'] as String?;
          final checkedBy = quality['checkedBy'] as String?;
          final checkedDate = quality['checkedDate'] as String?;

          if (status != null) {
            // Nájsť batch ID podľa batch number
            final db = await _db.database;
            final batches = await db.query(
              'production_batches',
              where: 'batch_number = ?',
              whereArgs: [batchNumber],
              limit: 1,
            );

            if (batches.isNotEmpty) {
              final batchId = batches.first['id'] as int;
              
              // Aktualizovať stav kvality šarže
              await db.update(
                'production_batches',
                {
                  'quality_status': status,
                  'quality_notes': notes,
                },
                where: 'id = ?',
                whereArgs: [batchId],
              );

              // Ak existuje kontrola kvality, vytvoriť záznam
              if (checkedDate != null && checkedBy != null) {
                final qualityCheck = QualityCheck(
                  batchId: batchId,
                  checkType: 'web_approval',
                  result: status,
                  notes: notes,
                  checkedDate: checkedDate,
                  checkedBy: checkedBy,
                );

                await db.insert(
                  'quality_checks',
                  qualityCheck.toMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing quality from API for $batchNumber: $e');
      rethrow;
    }
  }

  // Synchronizácia všetkých šarží z API
  Future<void> syncAllQualityFromAPI(List<String> batchNumbers) async {
    for (var batchNumber in batchNumbers) {
      try {
        await syncQualityFromAPI(batchNumber);
      } catch (e) {
        print('Error syncing quality for $batchNumber: $e');
        // Pokračovať s ďalšími šaržami aj keď jedna zlyhá
      }
    }
  }

  // Získanie aktuálneho stavu kvality z API
  Future<Map<String, dynamic>?> getQualityFromAPI(String batchNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL?batchNumber=$batchNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['quality'] != null) {
          return data['quality'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error getting quality from API for $batchNumber: $e');
      return null;
    }
  }
}

