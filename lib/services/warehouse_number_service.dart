import '../database/local_database.dart';

class WarehouseNumberService {
  static final WarehouseNumberService _instance = WarehouseNumberService._internal();
  factory WarehouseNumberService() => _instance;
  WarehouseNumberService._internal();

  /// Generuje nové poradové číslo produktu na sklade
  /// Formát: W-YYYY-NNNN (napr. W-2025-0001)
  Future<String> generateWarehouseNumber() async {
    final db = await LocalDatabase.instance.database;
    final year = DateTime.now().year;
    
    // Nájdite najvyššie číslo pre aktuálny rok
    final result = await db.rawQuery('''
      SELECT warehouse_number 
      FROM materials 
      WHERE warehouse_number IS NOT NULL 
        AND warehouse_number LIKE 'W-$year-%'
      ORDER BY warehouse_number DESC 
      LIMIT 1
    ''');
    
    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastNumber = result.first['warehouse_number'] as String?;
      if (lastNumber != null) {
        // Extrahuj číslo z formátu W-YYYY-NNNN
        final parts = lastNumber.split('-');
        if (parts.length == 3 && parts[0] == 'W' && parts[1] == year.toString()) {
          final numberPart = int.tryParse(parts[2]);
          if (numberPart != null) {
            nextNumber = numberPart + 1;
          }
        }
      }
    }
    
    // Formátuj číslo s leading zeros (4 číslice)
    return 'W-$year-${nextNumber.toString().padLeft(4, '0')}';
  }
}

