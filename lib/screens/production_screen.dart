import 'package:flutter/material.dart' hide Material;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../models/production.dart';
import '../models/production_type.dart';
import '../models/warehouse.dart';
import '../models/material.dart' as material_model;
import '../models/batch.dart';
import '../services/api_service.dart';
import 'production_form_screen.dart';

// Helper classes to match the provided code structure
class Product {
  final int id;
  final String name;
  final int quantity;

  Product({required this.id, required this.name, required this.quantity});
}

class ProductionBatch {
  final int? id;
  final String batchNumber;
  final String productName;
  final int quantity;
  final String productionDate;
  final String? notes;
  final String qualityStatus;
  final String? qualityNotes;

  ProductionBatch({
    this.id,
    required this.batchNumber,
    required this.productName,
    required this.quantity,
    required this.productionDate,
    this.notes,
    this.qualityStatus = 'pending',
    this.qualityNotes,
  });
}

class Alert {
  final String type;
  final material_model.Material material;
  final String message;

  Alert({
    required this.type,
    required this.material,
    required this.message,
  });
}

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Production> _productions = [];
  List<ProductionType> _productionTypes = [];
  List<Warehouse> _warehouse = [];
  List<material_model.Material> _materials = [];
  List<Batch> _batches = [];
  Map<String, List<Batch>> _batchesByDay = {};
  List<Map<String, dynamic>> _alerts = [];
  
  // Helper lists matching provided code structure
  List<Product> _products = [];
  List<ProductionBatch> _recentBatches = [];
  Map<String, List<ProductionBatch>> _batchesByDayFormatted = {};
  List<Alert> _alertsFormatted = [];
  
  bool _isLoading = true;
  bool _showByDays = true; // Zobrazenie podľa dní

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final productions = await apiService.getProductions();
      final types = await apiService.getProductionTypes();
      final warehouse = await apiService.getWarehouse();
      final materials = await apiService.getMaterials();
      final batches = await apiService.getBatches();
      final batchesByDay = await apiService.getBatchesByDays(days: 30);
      final alerts = await apiService.checkLowStock();
      
      // Debug: skontrolujme, či sa materiály načítali
      debugPrint('Načítané materiály: ${materials.length}');
      for (var material in materials) {
        debugPrint('  - ${material.name} (${material.id})');
      }
      debugPrint('Načítané warehouse položky: ${warehouse.length}');
      for (var item in warehouse) {
        debugPrint('  - Material ID: ${item.materialId}, Quantity: ${item.quantity}');
      }
      
      // Convert to helper objects matching provided code structure
      final products = <Product>[];
      final productMap = <String, int>{};
      for (var production in productions) {
        final typeName = production.productionTypeName ?? 'Neznámy';
        productMap[typeName] = (productMap[typeName] ?? 0) + production.quantity.toInt();
      }
      int productId = 1;
      for (var entry in productMap.entries) {
        products.add(Product(
          id: productId++,
          name: entry.key,
          quantity: entry.value,
        ));
      }
      
      // Convert batches to ProductionBatch
      final recentBatches = <ProductionBatch>[];
      for (var batch in batches.take(10)) {
        final production = productions.firstWhere(
          (p) => p.id == batch.productionId,
          orElse: () => Production(
            id: batch.productionId,
            productionTypeId: '',
            quantity: batch.quantity,
          ),
        );
        recentBatches.add(ProductionBatch(
          id: 1,
          batchNumber: batch.batchNumber,
          productName: production.productionTypeName ?? 'Neznámy',
          quantity: batch.quantity.toInt(),
          productionDate: batch.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          notes: null,
          qualityStatus: batch.status,
        ));
      }
      
      // Convert batchesByDay
      final batchesByDayFormatted = <String, List<ProductionBatch>>{};
      for (var entry in batchesByDay.entries) {
        final dayBatches = <ProductionBatch>[];
        for (var batch in entry.value) {
          final production = productions.firstWhere(
            (p) => p.id == batch.productionId,
            orElse: () => Production(
              id: batch.productionId,
              productionTypeId: '',
              quantity: batch.quantity,
            ),
          );
          dayBatches.add(ProductionBatch(
            id: 1,
            batchNumber: batch.batchNumber,
            productName: production.productionTypeName ?? 'Neznámy',
            quantity: batch.quantity.toInt(),
            productionDate: batch.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
            notes: null,
            qualityStatus: batch.status,
          ));
        }
        batchesByDayFormatted[entry.key] = dayBatches;
      }
      
      // Convert alerts
      final alertsFormatted = alerts.map((alertData) {
        material_model.Material material;
        if (alertData['material'] is material_model.Material) {
          material = alertData['material'] as material_model.Material;
        } else if (alertData['material'] is Map) {
          material = material_model.Material.fromJson(alertData['material'] as Map<String, dynamic>);
        } else {
          material = material_model.Material(
            id: '',
            name: 'Neznámy',
            unit: '',
          );
        }
        
        return Alert(
          type: alertData['type'] as String,
          material: material,
          message: alertData['message'] as String,
        );
      }).toList();
      
      setState(() {
        _productions = productions;
        _productionTypes = types;
        _warehouse = warehouse;
        _materials = materials;
        _batches = batches;
        _batchesByDay = batchesByDay;
        _alerts = alerts;
        _products = products;
        _recentBatches = recentBatches;
        _batchesByDayFormatted = batchesByDayFormatted;
        _alertsFormatted = alertsFormatted;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Chyba pri načítaní dát: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: $e')),
        );
      }
    }
  }

  double _getMaterialQuantity(String materialId) {
    final warehouseItem = _warehouse.firstWhere(
      (w) => w.materialId == materialId,
      orElse: () => Warehouse(
        id: '',
        materialId: materialId,
        quantity: 0,
      ),
    );
    return warehouseItem.quantity;
  }

  // Removed unused methods

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výroba'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Späť',
        ),
        actions: [
          IconButton(
            icon: Icon(_showByDays ? Icons.view_list : Icons.calendar_view_day),
            onPressed: () {
              setState(() {
                _showByDays = !_showByDays;
              });
            },
            tooltip: _showByDays ? 'Zobraziť zoznam' : 'Zobraziť podľa dní',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Obnoviť',
          ),
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => _showAddStockDialog(context),
            tooltip: 'Doplniť zásoby',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_alertsFormatted.isNotEmpty) ...[
                      _buildAlertsSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildMaterialsSection(),
                    const SizedBox(height: 24),
                    _buildProductionOverview(),
                    const SizedBox(height: 24),
                    _showByDays 
                        ? _buildProductionByDaysSection()
                        : _buildRecentProductionSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductionFormScreen(),
            ),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nová výroba'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildMaterialsSection() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.inventory_2, color: Colors.blue),
        title: const Text(
          'Aktuálny stav zásob',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_materials.length} materiálov',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showCreateMaterialDialog(context),
              tooltip: 'Vytvoriť nový materiál',
              color: Colors.blue,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.inventory, size: 20),
              onPressed: () => _showAddStockDialog(context),
              tooltip: 'Doplniť zásoby',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        children: [
          if (_materials.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Žiadne materiály',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pridajte materiály pomocou tlačidla +',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Column(
                children: _materials.map((material) {
                  return _buildCompactMaterialCard(material);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactMaterialCard(material_model.Material material) {
    return FutureBuilder<List<Warehouse>>(
      future: Provider.of<ApiService>(context, listen: false).getWarehouse(),
      builder: (context, snapshot) {
        double materialQuantity = 0;
        Color statusColor = Colors.green;
        bool isLowStock = false;
        IconData statusIcon = Icons.check_circle;
        String statusText = 'OK';
        double stockPercentage = 100.0;
        const double warningThreshold = 100.0;
        
        if (snapshot.hasData) {
          final item = snapshot.data!.firstWhere(
            (w) => w.materialId == material.id,
            orElse: () => Warehouse(
              id: '',
              materialId: material.id,
              quantity: 0,
            ),
          );
          materialQuantity = item.quantity;
          
          const double maxExpected = 500.0;
          stockPercentage = (materialQuantity / maxExpected * 100).clamp(0.0, 100.0);
          
          if (materialQuantity == 0) {
            statusColor = Colors.red.shade700;
            isLowStock = true;
            statusIcon = Icons.error_outline;
            statusText = 'KRITICKÉ';
            stockPercentage = 0;
          } else if (materialQuantity < 50) {
            statusColor = Colors.red.shade600;
            isLowStock = true;
            statusIcon = Icons.warning_amber_rounded;
            statusText = 'KRITICKÉ';
          } else if (materialQuantity < warningThreshold) {
            statusColor = Colors.orange.shade700;
            isLowStock = true;
            statusIcon = Icons.warning_amber_rounded;
            statusText = 'NÍZKE';
          } else {
            statusColor = Colors.green.shade700;
            isLowStock = false;
            statusIcon = Icons.check_circle_outline;
            statusText = 'OK';
          }
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isLowStock ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isLowStock ? statusColor.withOpacity(0.3) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              material.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${materialQuantity.toStringAsFixed(2)} ${material.unit}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: stockPercentage / 100,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${stockPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Removed _buildMaterialRow - replaced with _buildMaterialCard

  Widget _buildAlertsSection() {
    return Card(
      color: Colors.red.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Varovania (${_alertsFormatted.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alertsFormatted.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    alert.type == 'critical_stock' ? Icons.error : Icons.warning_amber,
                    color: alert.type == 'critical_stock' ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${alert.material.name}: ${alert.message}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionOverview() {
    final totalProducts = _products.fold<int>(
      0,
      (sum, product) => sum + product.quantity,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Výrobný prehľad',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Celkom vyrobených',
                    totalProducts.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Typy produktov',
                    _products.length.toString(),
                    Icons.category,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._products.map((product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    '${product.quantity} ks',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductionByDaysSection() {
    if (_batchesByDayFormatted.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Zatiaľ neboli zaznamenané žiadne výroby',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final sortedDays = _batchesByDayFormatted.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Najnovšie dni prvé

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Výroba podľa dní',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedDays.map((dayKey) => _buildDaySection(dayKey, _batchesByDayFormatted[dayKey]!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(String dayKey, List<ProductionBatch> batches) {
    final date = DateTime.parse('$dayKey 00:00:00');
    final dayNames = ['Pondelok', 'Utorok', 'Streda', 'Štvrtok', 'Piatok', 'Sobota', 'Nedeľa'];
    final dayName = dayNames[date.weekday - 1];
    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final totalQuantity = batches.fold<int>(0, (sum, batch) => sum + batch.quantity);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blue),
        title: Text(
          '$dateStr ($dayName)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${batches.length} šarží, celkom $totalQuantity ks',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.qr_code),
          onPressed: () => _showQRCodeDialog(context, date, batches),
          tooltip: 'Generovať QR kód',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: batches.map((batch) => _buildBatchCard(batch)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProductionSection() {
    if (_recentBatches.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Zatiaľ neboli zaznamenané žiadne výroby',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Posledné výroby',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._recentBatches.map((batch) => _buildBatchCard(batch)),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(ProductionBatch batch) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final date = DateTime.tryParse(batch.productionDate);

    Color qualityColor = Colors.grey;
    IconData qualityIcon = Icons.pending;
    String qualityText = 'Čaká na kontrolu';
    
    switch (batch.qualityStatus) {
      case 'passed':
        qualityColor = Colors.green;
        qualityIcon = Icons.check_circle;
        qualityText = 'Schválené';
        break;
      case 'failed':
        qualityColor = Colors.red;
        qualityIcon = Icons.cancel;
        qualityText = 'Zamietnuté';
        break;
      case 'warning':
        qualityColor = Colors.orange;
        qualityIcon = Icons.warning;
        qualityText = 'Varovanie';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(qualityIcon, color: qualityColor),
        title: Text(
          batch.productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Šarža: ${batch.batchNumber}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              date != null ? dateFormat.format(date) : batch.productionDate,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${batch.quantity} ks',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              qualityText,
              style: TextStyle(
                fontSize: 10,
                color: qualityColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (batch.notes != null && batch.notes!.isNotEmpty) ...[
                  Text(
                    'Poznámky: ${batch.notes}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                ],
                if (batch.qualityNotes != null && batch.qualityNotes!.isNotEmpty) ...[
                  Text(
                    'Kvalita: ${batch.qualityNotes}',
                    style: TextStyle(fontSize: 14, color: qualityColor),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showQualityDialog(context, batch),
                      icon: const Icon(Icons.verified_user, size: 18),
                      label: const Text('Kontrola kvality'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddStockDialog(BuildContext context) async {
    final selectedMaterials = <String, bool>{};
    final quantityControllers = <String, TextEditingController>{};
    final notesController = TextEditingController();

    for (var material in _materials) {
      selectedMaterials[material.id] = false;
      quantityControllers[material.id] = TextEditingController();
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Doplniť zásoby'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.select_all),
                          label: const Text('Vybrať všetko'),
                          onPressed: () {
                            setDialogState(() {
                              for (var key in selectedMaterials.keys) {
                                selectedMaterials[key] = true;
                              }
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.deselect),
                          label: const Text('Zrušiť výber'),
                          onPressed: () {
                            setDialogState(() {
                              for (var key in selectedMaterials.keys) {
                                selectedMaterials[key] = false;
                                quantityControllers[key]?.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  ..._materials.map((material) {
                    final isSelected = selectedMaterials[material.id] ?? false;
                    final controller = quantityControllers[material.id]!;
                    final quantity = _getMaterialQuantity(material.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedMaterials[material.id] = value ?? false;
                                      if (!(value ?? false)) {
                                        controller.clear();
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        material.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Aktuálne: ${quantity.toStringAsFixed(2)} ${material.unit}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: 'Množstvo na prijatie (${material.unit})',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.add),
                                ),
                                keyboardType: TextInputType.number,
                                enabled: isSelected,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Poznámky (voliteľné)',
                      border: OutlineInputBorder(),
                      helperText: 'Napríklad: číslo dodávky, dodávateľ',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Uložiť všetko'),
              onPressed: () async {
                final materialsToAdd = <String, double>{};

                for (var entry in selectedMaterials.entries) {
                  if (entry.value) {
                    final controller = quantityControllers[entry.key];
                    final quantity = double.tryParse(controller?.text ?? '');
                    if (quantity != null && quantity > 0) {
                      materialsToAdd[entry.key] = quantity;
                    }
                  }
                }

                if (materialsToAdd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vyberte aspoň jeden materiál a zadajte množstvo'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final apiService = Provider.of<ApiService>(context, listen: false);
                int successCount = 0;
                int failCount = 0;

                for (var entry in materialsToAdd.entries) {
                  try {
                    await apiService.addMaterialQuantity(entry.key, entry.value);
                    successCount++;
                  } catch (e) {
                    failCount++;
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Doplnenie zásob: $successCount úspešných, $failCount chýb',
                      ),
                      backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQRCodeDialog(
    BuildContext context,
    DateTime date,
    List<ProductionBatch> batches,
  ) async {
    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final totalQuantity = batches.fold<int>(0, (sum, batch) => sum + batch.quantity);
    final productsSummary = <String, int>{};
    
    for (var batch in batches) {
      productsSummary[batch.productName] = 
          (productsSummary[batch.productName] ?? 0) + batch.quantity;
    }

    final qrDataMap = {
      'date': date.toIso8601String(),
      'batches': batches.length,
      'total_quantity': totalQuantity,
      'products': productsSummary,
      'batch_numbers': batches.map((b) => b.batchNumber).toList(),
    };
    
    String qrData;
    if (kIsWeb) {
      // Import universal_html if needed
      final baseUrl = Uri.base.origin;
      final encodedData = base64Encode(utf8.encode(jsonEncode(qrDataMap)));
      qrData = '$baseUrl/production?data=$encodedData';
    } else {
      final encodedData = base64Encode(utf8.encode(jsonEncode(qrDataMap)));
      qrData = 'https://your-app.vercel.app/production?data=$encodedData';
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR Kód pre $dateStr'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dátum: $dateStr',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Počet šarží: ${batches.length}'),
                Text('Celkom vyrobených: $totalQuantity ks'),
                const SizedBox(height: 8),
                const Divider(),
                const Text(
                  'Produkty:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...productsSummary.entries.map((entry) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text('${entry.value} ks', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQualityDialog(BuildContext context, ProductionBatch batch) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    String selectedStatus = batch.qualityStatus;
    final notesController = TextEditingController(text: batch.qualityNotes ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kontrola kvality'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Šarža: ${batch.batchNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Stav kvality:'),
                RadioListTile<String>(
                  title: const Text('Čaká na kontrolu'),
                  value: 'pending',
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Schválené', style: TextStyle(color: Colors.green)),
                  value: 'passed',
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Varovanie', style: TextStyle(color: Colors.orange)),
                  value: 'warning',
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Zamietnuté', style: TextStyle(color: Colors.red)),
                  value: 'failed',
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámky k kvalite',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Find the actual batch ID from the batches list
                final actualBatch = _batches.firstWhere(
                  (b) => b.batchNumber == batch.batchNumber,
                  orElse: () => Batch(
                    id: '',
                    productionId: '',
                    batchNumber: batch.batchNumber,
                    quantity: batch.quantity.toDouble(),
                  ),
                );
                
                if (actualBatch.id.isNotEmpty) {
                  final result = await apiService.updateBatchQualityStatus(
                    actualBatch.id,
                    selectedStatus,
                    notes: notesController.text.isEmpty ? null : notesController.text,
                  );

                  if (result && context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stav kvality bol aktualizovaný'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Uložiť'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateMaterialDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    String selectedUnit = 'kg';

    final commonUnits = ['kg', 'l', 'm³', 'ks', 'm²', 'm'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vytvoriť nový materiál'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Názov materiálu *',
                    border: OutlineInputBorder(),
                    hintText: 'napr. Cement, Štrk 0/4',
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Jednotka *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: commonUnits.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedUnit = value ?? 'kg';
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Vlastná jednotka (voliteľné)',
                    border: OutlineInputBorder(),
                    hintText: 'Ak chcete zadať inú jednotku',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setDialogState(() {
                        selectedUnit = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Vytvoriť'),
              onPressed: () async {
                final name = nameController.text.trim();
                final unit = unitController.text.trim().isNotEmpty 
                    ? unitController.text.trim() 
                    : selectedUnit;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Zadajte názov materiálu'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Skontrolujeme, či už existuje
                final existing = _materials.firstWhere(
                  (m) => m.name.toLowerCase() == name.toLowerCase(),
                  orElse: () => material_model.Material(
                    id: '',
                    name: '',
                    unit: '',
                  ),
                );

                if (existing.id.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Materiál "$name" už existuje'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  await apiService.createMaterial(name, unit);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Materiál "$name" bol vytvorený'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chyba pri vytváraní materiálu: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

