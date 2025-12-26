export 'package:sqflite/sqflite.dart';

import 'package:sqflite/sqflite.dart' as sqflite;

// For mobile platforms (Android/iOS)
Future<String> getDatabasesPath() async {
  return sqflite.getDatabasesPath();
}

// No-op initialization for mobile
void initDatabase() {
  // Nothing to initialize on mobile
}
