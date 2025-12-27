import 'dart:convert';

import '../database/local_database.dart';

class SyncQueueService {
  final LocalDatabase _db = LocalDatabase.instance;

  Future<void> enqueueUpsert({
    required String table,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db.database;
    final payload = Map<String, dynamic>.from(data);
    payload['id'] = recordId;

    await db.insert('sync_queue', {
      'table_name': table,
      'record_id': recordId,
      'operation': 'upsert',
      'data': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> enqueueDelete({
    required String table,
    required int recordId,
  }) async {
    final db = await _db.database;
    await db.insert('sync_queue', {
      'table_name': table,
      'record_id': recordId,
      'operation': 'delete',
      'data': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await _db.database;
    return await db.query('sync_queue', orderBy: 'created_at');
  }

  Future<void> removeQueueItem(int queueId) async {
    final db = await _db.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  Future<void> clearQueue() async {
    final db = await _db.database;
    await db.delete('sync_queue');
  }

  /// Best-effort: sets `synced` flag if the table has it.
  Future<void> trySetSyncedFlag({
    required String table,
    required int recordId,
    required int synced,
  }) async {
    final db = await _db.database;
    try {
      await db.update(
        table,
        {'synced': synced},
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } catch (_) {
      // Table might not have `synced` column, ignore.
    }
  }
}


