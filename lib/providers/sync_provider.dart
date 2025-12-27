import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../services/sync_queue_service.dart';
import '../database/local_database.dart';
import 'app_settings_provider.dart';

class SyncProvider with ChangeNotifier {
  final Dio _dio = Dio(
    BaseOptions(
      // We handle status codes manually so sync can report HTTP errors cleanly.
      validateStatus: (_) => true,
    ),
  );
  final SyncQueueService _queue = SyncQueueService();
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isSyncing = false;
  String? _lastSyncError;
  String _baseUrl = 'http://localhost:3000';

  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;

  SyncProvider();

  void updateSettings(AppSettingsProvider settings) {
    _baseUrl = settings.apiBaseUrl.trim().isEmpty ? _baseUrl : settings.apiBaseUrl.trim();

    // Only start background activity after installation is complete.
    if (settings.installCompleted) {
      _startAutoSyncOnConnectivity();
    } else {
      _connectivitySub?.cancel();
      _connectivitySub = null;
    }
  }

  void _startAutoSyncOnConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) async {
      final hasConnection = result != ConnectivityResult.none;
      if (!hasConnection) return;
      // Auto-run sync when internet comes back.
      await syncAll();
    });
  }

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
      // Offline-first: primary source is sync_queue (JSON jobs).
      await _processSyncQueue();
    } catch (e) {
      _lastSyncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _processSyncQueue() async {
    final queue = await _queue.getQueue();

    for (final item in queue) {
      try {
        final table = item['table_name'] as String?;
        final recordId = item['record_id'] as int?;
        final operation = item['operation'] as String?;
        final queueId = item['id'] as int?;

        if (table == null || recordId == null || operation == null || queueId == null) {
          // Malformed item; drop it to avoid infinite loop.
          await _queue.removeQueueItem(queueId ?? -1);
          continue;
        }

        Map<String, dynamic>? data;

        final normalizedOperation = switch (operation) {
          'upsert' => 'upsert',
          'create' => 'upsert',
          'update' => 'upsert',
          'delete' => 'delete',
          _ => null,
        };

        if (normalizedOperation == null) {
          _lastSyncError = 'ERROR pri sync: neznáma operácia $operation';
          notifyListeners();
          continue;
        }

        if (normalizedOperation == 'upsert') {
          // Always prefer the latest local row over the stored queue payload.
          // This makes sync resilient to old non-JSON payloads and partial updates.
          final db = await LocalDatabase.instance.database;
          final rows = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [recordId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            data = Map<String, dynamic>.from(rows.first);
          } else {
            // Fallback to queued payload if the row no longer exists locally.
            final raw = item['data'];
            if (raw is String && raw.isNotEmpty) {
              try {
                data = (jsonDecode(raw) as Map).cast<String, dynamic>();
              } catch (_) {
                // Old format like "{id: 1, ...}" (not JSON) -> cannot decode
                data = null;
              }
            }
          }

          if (data == null) {
            _lastSyncError = 'ERROR pri sync $table#$recordId: lokálny záznam sa nenašiel';
            notifyListeners();
            continue; // keep queue item for now
          }

          // Never send local-only flags to the server schema.
          data.remove('synced');
        } else if (normalizedOperation == 'delete') {
          data = null;
        }

        final response = await _dio.post(
          '$_baseUrl/api/sync/$table',
          data: {
            'operation': normalizedOperation,
            'id': recordId,
            'data': data,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _queue.removeQueueItem(queueId);
          await _queue.trySetSyncedFlag(table: table, recordId: recordId, synced: 1);
        } else {
          _lastSyncError = 'ERROR (HTTP ${response.statusCode}) pri sync $table#$recordId';
          notifyListeners();
        }
      } catch (e) {
        _lastSyncError = 'ERROR pri sync: $e';
        notifyListeners();
        // Keep in queue for next sync
      }
    }
  }

  /// PC -> Server full upload.
  /// Sends all rows from selected local tables to the backend using upsert.
  /// This is useful for initial seeding or when you want to ensure server has
  /// everything (not only the queued changes).
  Future<void> uploadAllLocalToServer() async {
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
      // Keep this in sync with backend migrations / safe snapshot list.
      const tables = <String>[
        'materials',
        'aggregate_fractions',
        'recipes',
        'recipe_aggregates',
        'batches',
        'batch_materials',
        'quality_tests',
        'products',
      ];

      final db = await LocalDatabase.instance.database;

      for (final table in tables) {
        final rows = await db.query(table);
        for (final row in rows) {
          final id = row['id'];
          if (id is! int) {
            // If an unexpected schema sneaks in, skip row but keep going.
            continue;
          }

          final data = Map<String, dynamic>.from(row);
          data.remove('synced'); // local-only

          final resp = await _dio.post(
            '$_baseUrl/api/sync/$table',
            data: {'operation': 'upsert', 'id': id, 'data': data},
          );

          if (resp.statusCode == 200 || resp.statusCode == 201) {
            await _queue.trySetSyncedFlag(table: table, recordId: id, synced: 1);
          } else {
            _lastSyncError = 'ERROR (HTTP ${resp.statusCode}) pri full upload $table#$id';
            notifyListeners();
            // Stop early so user can fix server/schema issues.
            return;
          }
        }
      }
    } catch (e) {
      _lastSyncError = 'ERROR pri full upload: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Server -> PC overwrite-local sync.
  /// This downloads a server snapshot and replaces selected local tables.
  Future<void> downloadOverwriteLocal() async {
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
      // Tables we can safely snapshot from backend (matches existing backend migrations today).
      const tables = <String>[
        'materials',
        'aggregate_fractions',
        'recipes',
        'recipe_aggregates',
        'batches',
        'batch_materials',
        'quality_tests',
        'products',
      ];

      final snapshot = <String, List<Map<String, dynamic>>>{};
      for (final t in tables) {
        final resp = await _dio.get('$_baseUrl/api/sync/$t');
        final list = (resp.data as List).cast<dynamic>();
        snapshot[t] = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }

      // Apply snapshot in a transaction in FK-safe order.
      final db = await LocalDatabase.instance.database;
      await db.transaction((txn) async {
        // Clear local sync queue first (it no longer matches the overwritten state).
        await txn.delete('sync_queue');

        // Delete child -> parent order.
        await txn.delete('products');
        await txn.delete('quality_tests');
        await txn.delete('batch_materials');
        await txn.delete('batches');
        await txn.delete('recipe_aggregates');
        await txn.delete('recipes');
        await txn.delete('aggregate_fractions');
        await txn.delete('materials');

        // Insert parent -> child order.
        Future<void> insertAll(String table) async {
          final rows = snapshot[table] ?? const [];
          for (final row in rows) {
            final normalized = _normalizeRowForSqlite(row);
            normalized['synced'] = 1;
            await txn.insert(
              table,
              normalized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await insertAll('materials');
        await insertAll('aggregate_fractions');
        await insertAll('recipes');
        await insertAll('recipe_aggregates');
        await insertAll('batches');
        await insertAll('batch_materials');
        await insertAll('quality_tests');
        await insertAll('products');
      });
    } catch (e) {
      _lastSyncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _normalizeRowForSqlite(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    for (final entry in row.entries) {
      final v = entry.value;
      if (v is bool) {
        out[entry.key] = v ? 1 : 0;
      } else {
        out[entry.key] = v;
      }
    }
    return out;
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}









