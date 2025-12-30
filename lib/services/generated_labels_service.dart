// ====================================================================
// GENERATED LABELS SERVICE - Flutter appka
// ====================================================================
// Služba pre ukladanie a načítanie vygenerovaných štítkov

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/generated_labels_batch.dart';

class GeneratedLabelsService {
  static const String _storageKey = 'generated_labels_batches';
  static const int _maxBatches = 50; // Maximálny počet batchov v pamäti

  /// Uloží vygenerované štítky do lokálneho úložiska
  static Future<void> saveGeneratedBatch(GeneratedLabelsBatch batch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Načítaj existujúce batche
      final existingBatches = await getAllBatches();
      
      // Pridaj nový batch na začiatok
      existingBatches.insert(0, batch);
      
      // Odstráň staré batche ak je ich príliš veľa
      if (existingBatches.length > _maxBatches) {
        existingBatches.removeRange(_maxBatches, existingBatches.length);
      }
      
      // Ulož do SharedPreferences
      final batchesJson = existingBatches
          .map((b) => jsonEncode(b.toJson()))
          .toList();
      
      await prefs.setStringList(_storageKey, batchesJson);
    } catch (e) {
      throw Exception('Chyba pri ukladaní vygenerovaných štítkov: $e');
    }
  }

  /// Získá všetky uložené batche vygenerovaných štítkov
  static Future<List<GeneratedLabelsBatch>> getAllBatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final batchesJson = prefs.getStringList(_storageKey) ?? [];
      
      return batchesJson
          .map((json) {
            try {
              final decoded = jsonDecode(json) as Map<String, dynamic>;
              return GeneratedLabelsBatch.fromJson(decoded);
            } catch (e) {
              // Ak sa nepodarí dekódovať batch, preskočíme ho
              return null;
            }
          })
          .where((batch) => batch != null)
          .cast<GeneratedLabelsBatch>()
          .toList();
    } catch (e) {
      throw Exception('Chyba pri načítaní vygenerovaných štítkov: $e');
    }
  }

  /// Získá konkrétny batch podľa ID
  static Future<GeneratedLabelsBatch?> getBatchById(String id) async {
    try {
      final batches = await getAllBatches();
      return batches.where((batch) => batch.id == id).firstOrNull;
    } catch (e) {
      throw Exception('Chyba pri načítaní batchu: $e');
    }
  }

  /// Vymaže konkrétny batch
  static Future<void> deleteBatch(String id) async {
    try {
      final batches = await getAllBatches();
      batches.removeWhere((batch) => batch.id == id);
      
      final prefs = await SharedPreferences.getInstance();
      final batchesJson = batches
          .map((b) => jsonEncode(b.toJson()))
          .toList();
      
      await prefs.setStringList(_storageKey, batchesJson);
    } catch (e) {
      throw Exception('Chyba pri mazaní batchu: $e');
    }
  }

  /// Vymaže všetky batche
  static Future<void> clearAllBatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      throw Exception('Chyba pri mazaní všetkých batchov: $e');
    }
  }

  /// Vymaže staré batche (staršie ako zadaný počet dní)
  static Future<void> cleanupOldBatches({int daysToKeep = 30}) async {
    try {
      final batches = await getAllBatches();
      final validBatches = batches
          .where((batch) => !batch.isOlderThanDays(daysToKeep))
          .toList();
      
      final prefs = await SharedPreferences.getInstance();
      final batchesJson = validBatches
          .map((b) => jsonEncode(b.toJson()))
          .toList();
      
      await prefs.setStringList(_storageKey, batchesJson);
    } catch (e) {
      throw Exception('Chyba pri čistení starých batchov: $e');
    }
  }

  /// Získá štatistiky o vygenerovaných štítkoch
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final batches = await getAllBatches();
      
      int totalLabels = 0;
      int totalBatches = batches.length;
      DateTime? oldestBatch;
      DateTime? newestBatch;
      
      for (final batch in batches) {
        totalLabels += batch.labels.length;
        
        if (oldestBatch == null || batch.createdAt.isBefore(oldestBatch)) {
          oldestBatch = batch.createdAt;
        }
        
        if (newestBatch == null || batch.createdAt.isAfter(newestBatch)) {
          newestBatch = batch.createdAt;
        }
      }
      
      return {
        'totalLabels': totalLabels,
        'totalBatches': totalBatches,
        'oldestBatch': oldestBatch?.toIso8601String(),
        'newestBatch': newestBatch?.toIso8601String(),
        'averageLabelsPerBatch': totalBatches > 0 ? (totalLabels / totalBatches).round() : 0,
      };
    } catch (e) {
      throw Exception('Chyba pri získavaní štatistík: $e');
    }
  }

  /// Exportuje batch do JSON súboru pre zálohu
  static Future<String> exportBatchToJson(String id) async {
    try {
      final batch = await getBatchById(id);
      if (batch == null) {
        throw Exception('Batch nebol nájdený');
      }
      
      return jsonEncode(batch.toJson());
    } catch (e) {
      throw Exception('Chyba pri exporte batchu: $e');
    }
  }

  /// Importuje batch z JSON súboru
  static Future<GeneratedLabelsBatch> importBatchFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final batch = GeneratedLabelsBatch.fromJson(decoded);
      
      // Ulož importovaný batch
      await saveGeneratedBatch(batch);
      
      return batch;
    } catch (e) {
      throw Exception('Chyba pri importe batchu: $e');
    }
  }
}
