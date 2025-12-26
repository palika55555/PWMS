import '../database/local_database.dart';

class ReceiptNumberService {
  static final ReceiptNumberService _instance = ReceiptNumberService._internal();
  factory ReceiptNumberService() => _instance;
  ReceiptNumberService._internal();

  final LocalDatabase _db = LocalDatabase.instance;

  /// Generuje nové číslo príjemky vo formáte PR-YYYY-NNNN
  /// PR = Príjem, YYYY = rok, NNNN = sekvenčné číslo
  Future<String> generateReceiptNumber() async {
    final db = await _db.database;
    final now = DateTime.now();
    final year = now.year;
    final prefix = 'PR-$year-';
    
    // Nájdeme posledné číslo príjemky pre tento rok
    final lastReceipt = await db.query(
      'stock_movements',
      columns: ['receipt_number'],
      where: 'receipt_number LIKE ? AND movement_type = ?',
      whereArgs: ['$prefix%', 'receipt'],
      orderBy: 'receipt_number DESC',
      limit: 1,
    );
    
    int nextNumber = 1;
    if (lastReceipt.isNotEmpty && lastReceipt.first['receipt_number'] != null) {
      final lastNumber = lastReceipt.first['receipt_number'] as String;
      final parts = lastNumber.split('-');
      if (parts.length == 3) {
        final lastSeq = int.tryParse(parts[2]);
        if (lastSeq != null) {
          nextNumber = lastSeq + 1;
        }
      }
    }
    
    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  /// Kontroluje, či číslo príjemky už existuje
  Future<bool> receiptNumberExists(String receiptNumber) async {
    final db = await _db.database;
    final result = await db.query(
      'stock_movements',
      columns: ['id'],
      where: 'receipt_number = ?',
      whereArgs: [receiptNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}

