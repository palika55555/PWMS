import 'package:flutter/foundation.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart';

class DashboardProvider with ChangeNotifier {
  DatabaseProvider? _dbProvider;
  
  void setDatabaseProvider(DatabaseProvider provider) {
    _dbProvider = provider;
  }
  
  DatabaseProvider get dbProvider {
    if (_dbProvider == null) {
      throw StateError('DatabaseProvider not set');
    }
    return _dbProvider!;
  }
  
  int _todayBatches = 0;
  int _monthBatches = 0;
  int _todayQuantity = 0;
  int _monthQuantity = 0;
  int _lowStockCount = 0;
  int _approvedBatches = 0;
  double _approvedPercentage = 0.0;
  List<Batch> _recentBatches = [];
  List<Material> _lowStockMaterials = [];
  List<Map<String, dynamic>> _weeklyProduction = [];
  List<Material> _topMaterials = [];

  int get todayBatches => _todayBatches;
  int get monthBatches => _monthBatches;
  int get todayQuantity => _todayQuantity;
  int get monthQuantity => _monthQuantity;
  int get lowStockCount => _lowStockCount;
  int get approvedBatches => _approvedBatches;
  double get approvedPercentage => _approvedPercentage;
  List<Batch> get recentBatches => _recentBatches;
  List<Material> get lowStockMaterials => _lowStockMaterials;
  List<Map<String, dynamic>> get weeklyProduction => _weeklyProduction;
  List<Material> get topMaterials => _topMaterials;

  Future<void> loadDashboardData([DatabaseProvider? dbProvider]) async {
    final db = dbProvider ?? _dbProvider;
    if (db == null) {
      throw StateError('DatabaseProvider must be provided');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // Load batches
    final allBatches = await db.getBatches();
    
    // Today's batches
    _todayBatches = allBatches.where((b) {
      final batchDate = DateTime.parse(b.productionDate);
      return batchDate.isAtSameMomentAs(today);
    }).length;
    _todayQuantity = allBatches
        .where((b) {
          final batchDate = DateTime.parse(b.productionDate);
          return batchDate.isAtSameMomentAs(today);
        })
        .fold(0, (sum, b) => sum + b.quantity);

    // Month's batches
    _monthBatches = allBatches.where((b) {
      final batchDate = DateTime.parse(b.productionDate);
      return batchDate.isAfter(monthStart.subtract(const Duration(days: 1)));
    }).length;
    _monthQuantity = allBatches
        .where((b) {
          final batchDate = DateTime.parse(b.productionDate);
          return batchDate.isAfter(monthStart.subtract(const Duration(days: 1)));
        })
        .fold(0, (sum, b) => sum + b.quantity);

    // Approved batches
    _approvedBatches = allBatches
        .where((b) => b.qualityStatus == 'approved')
        .length;
    _approvedPercentage = allBatches.isEmpty
        ? 0.0
        : (_approvedBatches / allBatches.length) * 100;

    // Recent batches
    _recentBatches = allBatches.take(5).toList();

    // Low stock materials
    _lowStockMaterials = await db.checkLowStock();
    _lowStockCount = _lowStockMaterials.length;

    // Weekly production data
    _weeklyProduction = [];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final dayBatches = allBatches.where((b) {
        return b.productionDate.startsWith(dateStr);
      }).toList();
      final quantity = dayBatches.fold(0, (sum, b) => sum + b.quantity);
      
      _weeklyProduction.add({
        'date': dateStr,
        'day': _getDayName(date.weekday),
        'quantity': quantity,
        'batches': dayBatches.length,
      });
    }

    // Top materials by stock value
    final materials = await db.getMaterials();
    _topMaterials = materials
        .where((m) => m.currentStock > 0)
        .toList()
      ..sort((a, b) => b.currentStock.compareTo(a.currentStock));
    _topMaterials = _topMaterials.take(5).toList();

    notifyListeners();
  }

  String _getDayName(int weekday) {
    const days = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];
    return days[weekday - 1];
  }
}

