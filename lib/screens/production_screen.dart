import 'package:flutter/material.dart' hide Material;
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
import 'production_detail_screen.dart';
import 'batch_detail_screen.dart';

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
      setState(() {
        _productions = productions;
        _productionTypes = types;
        _warehouse = warehouse;
        _materials = materials;
        _batches = batches;
        _batchesByDay = batchesByDay;
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
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

  Color _getMaterialStatusColor(double quantity) {
    if (quantity == 0) return Colors.red;
    if (quantity < 100) return Colors.orange;
    return Colors.green;
  }

  Future<void> _deleteProduction(Production production) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdiť vymazanie'),
        content: Text('Naozaj chcete vymazať výrobu "${production.productionTypeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.deleteProduction(production.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Výroba bola vymazaná')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba pri vymazávaní: $e')),
          );
        }
      }
    }
  }

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
                    if (_alerts.isNotEmpty) ...[
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktuálny stav zásob',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._materials.map((material) {
              final quantity = _getMaterialQuantity(material.id);
              final statusColor = _getMaterialStatusColor(quantity);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${quantity.toStringAsFixed(2)} ${material.unit}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                          if (quantity == 0 || quantity < 100)
                            Text(
                              quantity == 0 ? 'KRITICKÉ!' : 'NÍZKE',
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

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
                  'Varovania (${_alerts.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    alert['type'] == 'critical_stock' ? Icons.error : Icons.warning_amber,
                    color: alert['type'] == 'critical_stock' ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${(alert['material'] as material_model.Material).name}: ${alert['message']}',
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
    final totalQuantity = _productions.fold<double>(
      0,
      (sum, production) => sum + production.quantity,
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
                    totalQuantity.toStringAsFixed(0),
                    Icons.inventory,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Typy výroby',
                    _productionTypes.length.toString(),
                    Icons.category,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._productionTypes.map((type) {
              final typeProductions = _productions.where((p) => p.productionTypeId == type.id);
              final typeQuantity = typeProductions.fold<double>(0, (sum, p) => sum + p.quantity);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '${typeQuantity.toStringAsFixed(0)} ks',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
    if (_batchesByDay.isEmpty) {
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

    final sortedDays = _batchesByDay.keys.toList()
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
            ...sortedDays.map((dayKey) => _buildDaySection(dayKey, _batchesByDay[dayKey]!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(String dayKey, List<Batch> batches) {
    final date = DateTime.parse('$dayKey 00:00:00');
    final dayNames = ['Pondelok', 'Utorok', 'Streda', 'Štvrtok', 'Piatok', 'Sobota', 'Nedeľa'];
    final dayName = dayNames[date.weekday - 1];
    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final totalQuantity = batches.fold<double>(0, (sum, batch) => sum + batch.quantity);

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
          '${batches.length} šarží, celkom ${totalQuantity.toStringAsFixed(0)} ks',
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
    if (_productions.isEmpty) {
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
            ..._productions.take(10).map((production) => _buildProductionCard(production)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCard(Production production) {
    final batch = _batches.firstWhere(
      (b) => b.productionId == production.id,
      orElse: () => Batch(
        id: '',
        productionId: production.id,
        batchNumber: 'N/A',
        quantity: 0,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              production.quantity.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          production.productionTypeName ?? 'Neznámy typ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (batch.batchNumber != 'N/A')
              Text('Šarža: ${batch.batchNumber}'),
            Text(
              production.productionDate != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(production.productionDate!)
                  : 'N/A',
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductionDetailScreen(production: production),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBatchCard(Batch batch) {
    final production = _productions.firstWhere(
      (p) => p.id == batch.productionId,
      orElse: () => Production(
        id: batch.productionId,
        productionTypeId: '',
        quantity: batch.quantity,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.inventory_2, color: Colors.purple),
        title: Text(
          production.productionTypeName ?? 'Neznámy typ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Šarža: ${batch.batchNumber}'),
        trailing: Text(
          '${batch.quantity.toStringAsFixed(0)} ks',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BatchDetailScreen(batch: batch),
            ),
          );
        },
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
    List<Batch> batches,
  ) async {
    final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final totalQuantity = batches.fold<double>(0, (sum, batch) => sum + batch.quantity);
    final productsSummary = <String, double>{};
    
    for (var batch in batches) {
      final production = _productions.firstWhere(
        (p) => p.id == batch.productionId,
        orElse: () => Production(
          id: batch.productionId,
          productionTypeId: '',
          quantity: batch.quantity,
        ),
      );
      final productName = production.productionTypeName ?? 'Neznámy';
      productsSummary[productName] = (productsSummary[productName] ?? 0) + batch.quantity;
    }

    final qrData = jsonEncode({
      'date': date.toIso8601String(),
      'batches': batches.length,
      'total_quantity': totalQuantity,
      'products': productsSummary,
      'batch_numbers': batches.map((b) => b.batchNumber).toList(),
    });

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
                Text('Celkom vyrobených: ${totalQuantity.toStringAsFixed(0)} ks'),
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
                        Text('${entry.value.toStringAsFixed(0)} ks', 
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
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
