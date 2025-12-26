import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../database/local_database.dart';
import '../config/api_config.dart';

class SyncProvider with ChangeNotifier {
  final LocalDatabase _db = LocalDatabase.instance;
  final Dio _dio = Dio();
  bool _isSyncing = false;
  String? _lastSyncError;

  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;

  Future<bool> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;

    final hasConnection = await checkConnectivity();
    if (!hasConnection) {
      _lastSyncError = 'Žiadne pripojenie na internet';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      // Sync materials
      await _syncMaterials();
      
      // Sync recipes
      await _syncRecipes();
      
      // Sync batches
      await _syncBatches();
      
      // Process sync queue
      await _processSyncQueue();
    } catch (e) {
      _lastSyncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncMaterials() async {
    final db = await _db.database;
    
    // Get unsynced materials
    final unsynced = await db.query(
      'materials',
      where: 'synced = 0',
    );

    for (final material in unsynced) {
      try {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/api/materials',
          data: material,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'materials',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [material['id']],
          );
        }
      } catch (e) {
        // Add to sync queue for retry
        await db.insert('sync_queue', {
          'table_name': 'materials',
          'record_id': material['id'],
          'operation': 'create',
          'data': material.toString(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _syncRecipes() async {
    final db = await _db.database;
    final unsynced = await db.query('recipes', where: 'synced = 0');

    for (final recipe in unsynced) {
      try {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/api/recipes',
          data: recipe,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'recipes',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [recipe['id']],
          );
        }
      } catch (e) {
        await db.insert('sync_queue', {
          'table_name': 'recipes',
          'record_id': recipe['id'],
          'operation': 'create',
          'data': recipe.toString(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _syncBatches() async {
    final db = await _db.database;
    final unsynced = await db.query('batches', where: 'synced = 0');

    for (final batch in unsynced) {
      try {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/api/batches',
          data: batch,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'batches',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );
        }
      } catch (e) {
        await db.insert('sync_queue', {
          'table_name': 'batches',
          'record_id': batch['id'],
          'operation': 'create',
          'data': batch.toString(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _processSyncQueue() async {
    final db = await _db.database;
    final queue = await db.query('sync_queue', orderBy: 'created_at');

    for (final item in queue) {
      try {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/api/${item['table_name']}',
          data: item['data'],
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      } catch (e) {
        // Keep in queue for next sync
      }
    }
  }
}






