// Re-export Database type and functions
export 'package:sqflite/sqflite.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// Initialize FFI for desktop platforms
void initDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

// Re-export getDatabasesPath for mobile compatibility
Future<String> getDatabasesPath() async {
  // This won't be used on desktop, but we need it for the interface
  throw UnimplementedError('getDatabasesPath not used on desktop');
}
