import 'package:flutter/material.dart' hide Material;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../services/material_service.dart';
import '../services/production_service.dart';
import '../services/alert_service.dart';
import '../services/quality_service.dart';
import '../services/recipe_service.dart';
import '../models/material.dart' as models;
import '../models/product.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final MaterialService _materialService = MaterialService();
  final ProductionService _productionService = ProductionService();
  final AlertService _alertService = AlertService();
  final RecipeService _recipeService = RecipeService();
  
  List<models.Material> _materials = [];
  List<Product> _products = [];
  List<ProductionBatch> _recentBatches = [];
  Map<String, List<ProductionBatch>> _batchesByDay = {};
  List<Alert> _alerts = [];
  bool _isLoading = true;
  bool _showByDays = true; // Zobrazenie podľa dní

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final materials = await _materialService.getAllMaterials();
    final products = await _productionService.getAllProducts();
    final batches = await _productionService.getProductionBatches(limit: 10);
    final batchesByDay = await _productionService.getProductionByDays(days: 30);
    final alerts = await _alertService.checkLowStock();
    
    setState(() {
      _materials = materials;
      _products = products;
      _recentBatches = batches;
      _batchesByDay = batchesByDay;
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výroba'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProductionDialog(context),
            tooltip: 'Zaznamenať výrobu',
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
            ..._materials.map((material) => _buildMaterialRow(material)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(models.Material material) {
    Color statusColor = Colors.green;
    if (material.isLowStock) {
      statusColor = material.quantity == 0 ? Colors.red : Colors.orange;
    }

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
                if (material.isLowStock)
                  Text(
                    'Min: ${material.minQuantity.toStringAsFixed(2)} ${material.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
                  '${material.quantity.toStringAsFixed(2)} ${material.unit}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
                if (material.isLowStock)
                  Text(
                    material.quantity == 0 ? 'KRITICKÉ!' : 'NÍZKE',
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
        color: color.withValues(alpha: 0.1),
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

  Widget _buildDaySection(String dayKey, List<ProductionBatch> batches) {
    final date = DateTime.parse('$dayKey 00:00:00');
    // Použijeme jednoduchšie formátovanie bez lokalizácie
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

  Future<void> _showProductionDialog(BuildContext context) async {
    int? selectedProductId;
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    bool useRecipe = true;
    
    final materialControllers = <int, TextEditingController>{};
    for (var material in _materials) {
      materialControllers[material.id!] = TextEditingController();
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zaznamenať výrobu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Produkt',
                    border: OutlineInputBorder(),
                  ),
                  items: _products.map((product) {
                    return DropdownMenuItem<int>(
                      value: product.id,
                      child: Text(product.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedProductId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Množstvo (ks)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) async {
                    if (selectedProductId != null && useRecipe) {
                      final quantity = int.tryParse(value);
                      if (quantity != null && quantity > 0) {
                        final usage = await _recipeService.calculateMaterialUsage(
                          selectedProductId!,
                          quantity,
                        );
                        setDialogState(() {
                          for (var entry in usage.entries) {
                            final controller = materialControllers[entry.key];
                            if (controller != null) {
                              controller.text = entry.value.toStringAsFixed(2);
                            }
                          }
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Použiť receptúru (automatický výpočet)'),
                  value: useRecipe,
                  onChanged: (value) {
                    setDialogState(() {
                      useRecipe = value ?? true;
                      if (!useRecipe) {
                        // Vymazať hodnoty ak sa nepoužíva receptúra
                        for (var controller in materialControllers.values) {
                          controller.clear();
                        }
                      }
                    });
                  },
                ),
                const Divider(),
                const Text(
                  'Spotreba materiálov:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._materials.map((material) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: materialControllers[material.id!],
                    decoration: InputDecoration(
                      labelText: '${material.name} (${material.unit})',
                      border: const OutlineInputBorder(),
                      hintText: '0.0',
                      enabled: !useRecipe,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámky (voliteľné)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                if (selectedProductId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vyberte produkt')),
                  );
                  return;
                }

                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vyplňte množstvo')),
                  );
                  return;
                }

                Map<int, double>? materialsUsed;
                if (!useRecipe) {
                  materialsUsed = <int, double>{};
                  for (var entry in materialControllers.entries) {
                    final value = double.tryParse(entry.value.text);
                    if (value != null && value > 0) {
                      materialsUsed[entry.key] = value;
                    }
                  }
                }

                final result = await _productionService.recordProduction(
                  productId: selectedProductId!,
                  quantity: quantity,
                  materialsUsed: materialsUsed,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                  useRecipe: useRecipe,
                );

                if (context.mounted) {
                  if (result['success'] == true) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Výroba bola zaznamenaná\nŠarža: ${result['batchNumber']}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['error'] ?? 'Chyba pri zaznamenávaní výroby'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
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

  Future<void> _showQualityDialog(BuildContext context, ProductionBatch batch) async {
    final qualityService = QualityService();
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
                final result = await qualityService.updateBatchQualityStatus(
                  batch.id!,
                  selectedStatus,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                if (result > 0 && context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stav kvality bol aktualizovaný'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Uložiť'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddStockDialog(BuildContext context) async {
    final selectedMaterials = <int, bool>{};
    final quantityControllers = <int, TextEditingController>{};
    final notesController = TextEditingController();

    // Inicializácia - všetky materiály sú nevybrané
    for (var material in _materials) {
      selectedMaterials[material.id!] = false;
      quantityControllers[material.id!] = TextEditingController();
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
                    final isSelected = selectedMaterials[material.id!] ?? false;
                    final controller = quantityControllers[material.id!]!;

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
                                      selectedMaterials[material.id!] = value ?? false;
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
                                        'Aktuálne: ${material.quantity.toStringAsFixed(2)} ${material.unit}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      if (material.minQuantity > 0)
                                        Text(
                                          'Min: ${material.minQuantity.toStringAsFixed(2)} ${material.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
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
                final materialsToAdd = <int, Map<String, dynamic>>{};

                for (var entry in selectedMaterials.entries) {
                  if (entry.value) {
                    final controller = quantityControllers[entry.key];
                    final quantity = double.tryParse(controller?.text ?? '');
                    if (quantity != null && quantity > 0) {
                      materialsToAdd[entry.key] = {
                        'material': _materials.firstWhere((m) => m.id == entry.key),
                        'quantity': quantity,
                      };
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

                // Hromadné pridanie zásob
                final results = <String>[];
                int successCount = 0;
                int failCount = 0;

                for (var entry in materialsToAdd.entries) {
                  final material = entry.value['material'] as models.Material;
                  final quantity = entry.value['quantity'] as double;

                  final result = await _materialService.addMaterialQuantity(
                    entry.key,
                    quantity,
                  );

                  if (result > 0) {
                    successCount++;
                    results.add(
                      '✓ ${material.name}: +${quantity.toStringAsFixed(2)} ${material.unit} '
                      '(nový stav: ${(material.quantity + quantity).toStringAsFixed(2)} ${material.unit})',
                    );
                  } else {
                    failCount++;
                    results.add('✗ ${material.name}: Chyba pri pridávaní');
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doplnenie zásob: $successCount úspešných, $failCount chýb',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...results.take(5).map((r) => Text(
                            r,
                            style: const TextStyle(fontSize: 12),
                          )),
                          if (results.length > 5)
                            Text(
                              '... a ďalších ${results.length - 5}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                      backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Zobraziť všetko',
                        onPressed: () {
                          // Môžeme pridať detailný dialóg neskôr
                        },
                      ),
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
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Uložiť QR kód'),
            onPressed: () async {
              // TODO: Implementovať uloženie QR kódu ako obrázok
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funkcia uloženia bude pridaná')),
              );
            },
          ),
        ],
      ),
    );
  }
}
