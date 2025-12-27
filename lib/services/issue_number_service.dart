import '../database/local_database.dart';

class IssueNumberService {
  static final IssueNumberService _instance = IssueNumberService._internal();
  factory IssueNumberService() => _instance;
  IssueNumberService._internal();

  final LocalDatabase _db = LocalDatabase.instance;

  /// Generuje nové číslo výdajky vo formáte VY-YYYY-NNNN
  /// VY = Výdaj, YYYY = rok, NNNN = sekvenčné číslo
  Future<String> generateIssueNumber() async {
    final db = await _db.database;
    final now = DateTime.now();
    final year = now.year;
    final prefix = 'VY-$year-';

    final lastIssue = await db.query(
      'stock_movements',
      columns: ['receipt_number'],
      where: 'receipt_number LIKE ? AND movement_type = ?',
      whereArgs: ['$prefix%', 'issue'],
      orderBy: 'receipt_number DESC',
      limit: 1,
    );

    int nextNumber = 1;
    if (lastIssue.isNotEmpty && lastIssue.first['receipt_number'] != null) {
      final lastNumber = lastIssue.first['receipt_number'] as String;
      final parts = lastNumber.split('-');
      if (parts.length == 3) {
        final lastSeq = int.tryParse(parts[2]);
        if (lastSeq != null) nextNumber = lastSeq + 1;
      }
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }
}


