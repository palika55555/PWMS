import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class BatchMaterialsScreen extends StatefulWidget {
  final int batchId;
  final int recipeId;
  final int quantity;

  const BatchMaterialsScreen({
    super.key,
    required this.batchId,
    required this.recipeId,
    required this.quantity,
  });

  @override
  State<BatchMaterialsScreen> createState() => _BatchMaterialsScreenState();
}

class _BatchMaterialsScreenState extends State<BatchMaterialsScreen> {
  List<Map<String, dynamic>> _batchMaterials = [];
  List<Map<String, dynamic>> _recipeAggregates = [];
  Recipe? _recipe;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    // Load recipe
    final recipe = await dbProvider.getRecipe(widget.recipeId);
    
    // Load recipe aggregates
    final aggregates = await dbProvider.getRecipeAggregates(widget.recipeId);
    
    // Load existing batch materials
    final batchMaterials = await dbProvider.getBatchMaterials(widget.batchId);
    
    setState(() {
      _recipe = recipe;
      _recipeAggregates = aggregates;
      _batchMaterials = batchMaterials;
      _loading = false;
    });
    
    // If no batch materials exist, create them from recipe
    if (_batchMaterials.isEmpty && _recipe != null) {
      await _initializeBatchMaterials();
    }
  }

  Future<void> _initializeBatchMaterials() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    // Add cement
    if (_recipe!.cementAmount > 0) {
      final cementMaterials = await dbProvider.getMaterials();
      final cement = cementMaterials.firstWhere(
        (m) => m.type == 'cement',
        orElse: () => cementMaterials.first,
      );
      
      await dbProvider.insertBatchMaterial({
        'batch_id': widget.batchId,
        'material_id': cement.id!,
        'fraction_id': null,
        'planned_amount': _recipe!.cementAmount * widget.quantity,
        'actual_amount': null,
      });
    }
    
    // Add water
    if (_recipe!.waterAmount > 0) {
      final waterMaterials = await dbProvider.getMaterials();
      final water = waterMaterials.firstWhere(
        (m) => m.type == 'water',
        orElse: () => waterMaterials.first,
      );
      
      await dbProvider.insertBatchMaterial({
        'batch_id': widget.batchId,
        'material_id': water.id!,
        'fraction_id': null,
        'planned_amount': _recipe!.waterAmount * widget.quantity,
        'actual_amount': null,
      });
    }
    
    // Add plasticizer if exists
    if (_recipe!.plasticizerAmount != null && _recipe!.plasticizerAmount! > 0) {
      final plasticizerMaterials = await dbProvider.getMaterials();
      final plasticizer = plasticizerMaterials.firstWhere(
        (m) => m.type == 'plasticizer',
        orElse: () => plasticizerMaterials.first,
      );
      
      await dbProvider.insertBatchMaterial({
        'batch_id': widget.batchId,
        'material_id': plasticizer.id!,
        'fraction_id': null,
        'planned_amount': _recipe!.plasticizerAmount! * widget.quantity,
        'actual_amount': null,
      });
    }
    
    // Add aggregates from recipe
    for (final aggregate in _recipeAggregates) {
      await dbProvider.insertBatchMaterial({
        'batch_id': widget.batchId,
        'material_id': (aggregate['material'] as material_model.Material).id!,
        'fraction_id': aggregate['fraction']?['id'],
        'planned_amount': (aggregate['amount'] as num).toDouble() * widget.quantity,
        'actual_amount': null,
      });
    }
    
    await _loadData();
  }

  Future<void> _updateActualAmount(int batchMaterialId, double amount) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await dbProvider.updateBatchMaterial(batchMaterialId, amount);
    await _loadData();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Množstvo bolo aktualizované'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiály šarže'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prehľad materiálov',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Množstvo produktov: ${widget.quantity} ks'),
                  if (_recipe != null)
                    Text('Receptúra: ${_recipe!.name}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Materials list
          ..._batchMaterials.map((bm) => _buildMaterialCard(bm)),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> batchMaterial) {
    final material = batchMaterial['material'] as material_model.Material?;
    final fraction = batchMaterial['fraction'] as Map<String, dynamic>?;
    final plannedAmount = (batchMaterial['planned_amount'] as num).toDouble();
    final actualAmount = batchMaterial['actual_amount'] as double?;
    final id = batchMaterial['id'] as int;
    
    if (material == null) return const SizedBox.shrink();
    
    // Map material types to Slovak names
    final typeNames = {
      'cement': 'Cement',
      'water': 'Voda',
      'plasticizer': 'Plastifikátor',
      'aggregate': 'Agregát',
    };
    
    final typeName = typeNames[material.type] ?? material.type;
    
    // For cement, water, plasticizer - show type name prominently
    // For aggregates - show material name with fraction if available
    final materialName = (material.type == 'cement' || material.type == 'water' || material.type == 'plasticizer')
        ? typeName
        : (fraction != null
            ? '${material.name} - ${fraction['fraction_name']}'
            : material.name);
    
    final unit = material.unit;
    final difference = actualAmount != null
        ? actualAmount - plannedAmount
        : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    materialName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (actualAmount != null && difference != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difference.abs() < plannedAmount * 0.05
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      difference > 0 ? '+${difference.toStringAsFixed(2)}' : difference.toStringAsFixed(2),
                      style: TextStyle(
                        color: difference.abs() < plannedAmount * 0.05
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plánované',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${plannedAmount.toStringAsFixed(2)} $unit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skutočné',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        actualAmount != null
                            ? '${actualAmount.toStringAsFixed(2)} $unit'
                            : 'Nie je zadané',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: actualAmount != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Zadať skutočné množstvo ($unit)',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.edit),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (value) {
                final amount = double.tryParse(value);
                if (amount != null && amount >= 0) {
                  _updateActualAmount(id, amount);
                }
              },
              controller: TextEditingController(
                text: actualAmount?.toStringAsFixed(2) ?? '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


