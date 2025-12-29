import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/local_database.dart';

class DbBackupService {
  DbBackupService();

  Future<String> getDbFilePath() async {
    return await LocalDatabase.instance.getDatabaseFilePath();
  }

  Future<String> backupNow({required String targetDir}) async {
    final dbPath = await getDbFilePath();
    final src = File(dbPath);
    if (!await src.exists()) {
      throw Exception('DB súbor neexistuje: $dbPath');
    }

    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Close DB so Windows doesn't keep the file locked.
    await LocalDatabase.instance.closeDatabase();

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    final backupPath = p.join(dir.path, 'problock_$ts.db');

    await src.copy(backupPath);

    // Reopen DB (lazy init).
    await LocalDatabase.instance.database;

    return backupPath;
  }

  Future<void> restoreFromFile({required String sourcePath}) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw Exception('Záloha neexistuje: $sourcePath');
    }

    final dbPath = await getDbFilePath();
    final dbFile = File(dbPath);

    // Close DB so Windows doesn't keep the file locked.
    await LocalDatabase.instance.closeDatabase();

    // Ensure parent exists.
    final parent = dbFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    // Replace.
    await src.copy(dbPath);

    // Reopen DB (and run migrations if needed).
    await LocalDatabase.instance.database;
  }
}




