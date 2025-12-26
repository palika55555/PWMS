import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../screens/warehouse/bulk_receipt_screen.dart';
import 'create_batch_screen.dart';

class ProductionInputScreen extends StatefulWidget {
  const ProductionInputScreen({super.key});

  @override
  State<ProductionInputScreen> createState() => _ProductionInputScreenState();
}

class _ProductionInputScreenState extends State<ProductionInputScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedProductType = 'tvarnice';
  Recipe? _selectedRecipe;
  final _quantityController = TextEditingController();
  List<Recipe> _recipes = [];
  List<Map<String, dynamic>> _requiredMaterials = [];
  Map<int, material_model.Material> _materialsMap = {}; // Material ID -> Material
  bool _loading = true;

  final List<String> _productTypes = [
    'tvarnice',
    'dlazba',
    'obrubniky',
    'iné',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final recipes = await dbProvider.getRecipes();
    final materials = await dbProvider.getMaterials();
    
    final materialsMap = <int, material_model.Material>{};
    for (final m in materials) {
      if (m.id != null) {
        materialsMap[m.id!] = m;
      }
    }
    
    setState(() {
      _recipes = recipes;
      _materialsMap = materialsMap;
      if (recipes.isNotEmpty) {
        // Filter recipes by product type if possible
        final matchingRecipes = recipes.where((r) => 
          r.productType.toLowerCase() == _selectedProductType.toLowerCase()
        ).toList();
        // Select matching recipe or first available
        _selectedRecipe = matchingRecipes.isNotEmpty 
            ? matchingRecipes.first 
            : recipes.first;
      } else {
        _selectedRecipe = null;
      }
      _loading = false;
    });
    _calculateMaterials();
  }

  Future<void> _calculateMaterials() async {
    if (_selectedRecipe == null) {
      setState(() {
        _requiredMaterials = [];
      });
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      setState(() {
        _requiredMaterials = [];
      });
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final aggregates = await dbProvider.getRecipeAggregates(_selectedRecipe!.id!);
    
    final List<Map<String, dynamic>> materials = [];
    
    // Add cement
    if (_selectedRecipe!.cementAmount > 0) {
      final cementMaterials = _materialsMap.values.where((m) => m.type == 'cement').toList();
      final cementMaterial = cementMaterials.isNotEmpty ? cementMaterials.first : null;
      
      materials.add({
        'name': 'Cement',
        'amount': _selectedRecipe!.cementAmount * quantity,
        'unit': 'kg',
        'type': 'cement',
        'material_id': cementMaterial?.id,
        'material': cementMaterial,
      });
    }
    
    // Add water
    if (_selectedRecipe!.waterAmount > 0) {
      materials.add({
        'name': 'Voda',
        'amount': _selectedRecipe!.waterAmount * quantity,
        'unit': 'l',
        'type': 'water',
        'material_id': null,
        'material': null,
      });
    }
    
    // Add plasticizer
    if (_selectedRecipe!.plasticizerAmount != null && _selectedRecipe!.plasticizerAmount! > 0) {
      final plasticizerMaterials = _materialsMap.values.where((m) => m.type == 'plasticizer').toList();
      final plasticizerMaterial = plasticizerMaterials.isNotEmpty ? plasticizerMaterials.first : null;
      
      materials.add({
        'name': 'Plastifikátor',
        'amount': _selectedRecipe!.plasticizerAmount! * quantity,
        'unit': 'l',
        'type': 'plasticizer',
        'material_id': plasticizerMaterial?.id,
        'material': plasticizerMaterial,
      });
    }
    
    // Add aggregates
    for (final aggregate in aggregates) {
      final material = aggregate['material'] as material_model.Material?;
      final fraction = aggregate['fraction'] as Map<String, dynamic>?;
      final amount = (aggregate['amount'] as num).toDouble();
      
      if (material != null) {
        final name = fraction != null
            ? '${material.name} - ${fraction['fraction_name']}'
            : material.name;
        
        materials.add({
          'name': name,
          'amount': amount * quantity,
          'unit': material.unit,
          'type': 'aggregate',
          'fraction': fraction?['fraction_name'],
          'material_id': material.id,
          'material': material,
        });
      }
    }
    
    setState(() {
      _requiredMaterials = materials;
    });
  }

  void _createBatch() {
    if (!_formKey.currentState!.validate() || _selectedRecipe == null) {
      return;
    }

    // Navigate to create batch screen with pre-filled data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBatchScreen(
          preSelectedRecipe: _selectedRecipe,
          preFilledQuantity: int.tryParse(_quantityController.text),
        ),
      ),
    );
  }

  Future<void> _stockMaterials() async {
    // Filter materials that can be stocked (have material_id)
    final stockableMaterials = _requiredMaterials.where((m) => m['material_id'] != null).toList();
    
    if (stockableMaterials.isEmpty) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Žiadne materiály na naskladnenie'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
        ),
      );
      return;
    }

    // Navigate to receipt screen - user can stock materials there
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BulkReceiptScreen(),
      ),
    ).then((_) {
      // Reload materials to update stock
      _loadRecipes();
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product type selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Typ produktu',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedProductType,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte typ produktu *',
                        border: OutlineInputBorder(),
                      ),
                      items: _productTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type[0].toUpperCase() + type.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProductType = value!;
                          // Try to find matching recipe
                          final matchingRecipes = _recipes.where((r) => 
                            r.productType.toLowerCase() == value.toLowerCase()
                          ).toList();
                          _selectedRecipe = matchingRecipes.isNotEmpty 
                              ? matchingRecipes.first 
                              : _recipes.isNotEmpty ? _recipes.first : null;
                        });
                        _calculateMaterials();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Recipe selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receptúra',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Recipe>(
                      value: _selectedRecipe,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte receptúru *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.menu_book),
                      ),
                      isExpanded: true,
                      items: _recipes.map((recipe) {
                        return DropdownMenuItem<Recipe>(
                          value: recipe,
                          child: Text(
                            recipe.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (recipe) {
                        setState(() {
                          _selectedRecipe = recipe;
                        });
                        _calculateMaterials();
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vyberte receptúru';
                        }
                        return null;
                      },
                    ),
                    if (_recipes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Žiadne receptúry nie sú k dispozícii. Vytvorte receptúru v sekcii "Receptúry".',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Quantity input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Množstvo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Množstvo ${_selectedProductType} (ks) *',
                        border: const OutlineInputBorder(),
                        helperText: 'Zadajte počet kusov, ktoré chcete vyrobiť',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateMaterials(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zadajte množstvo';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Zadajte platné množstvo';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Required materials preview
            if (_requiredMaterials.isNotEmpty) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Potrebné materiály',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                Text(
                                  'Pre ${_quantityController.text.isEmpty ? "0" : _quantityController.text} ks ${_selectedProductType}',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ..._requiredMaterials.map((m) {
                        final material = m['material'] as material_model.Material?;
                        final currentStock = material?.currentStock ?? 0;
                        final requiredAmount = (m['amount'] as num).toDouble();
                        final isLowStock = material != null && currentStock < requiredAmount;
                        final hasStock = material != null;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isLowStock ? Colors.orange.shade50 : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            m['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: isLowStock ? Colors.orange.shade900 : null,
                                            ),
                                          ),
                                          if (isLowStock) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.warning,
                                              color: Colors.orange.shade700,
                                              size: 18,
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (m['fraction'] != null)
                                        Text(
                                          'Frakcia: ${m['fraction']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (hasStock)
                                        Text(
                                          'Sklad: ${currentStock.toStringAsFixed(2)} ${m['unit']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isLowStock ? Colors.orange.shade700 : Colors.grey.shade600,
                                            fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLowStock ? Colors.orange.shade100 : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${requiredAmount.toStringAsFixed(2)} ${m['unit']}',
                                        style: TextStyle(
                                          color: isLowStock ? Colors.orange.shade900 : Colors.blue.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (hasStock && isLowStock)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Chýba: ${(requiredAmount - currentStock).toStringAsFixed(2)} ${m['unit']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      // Stock receipt button
                      if (_requiredMaterials.any((m) => m['material_id'] != null))
                        ElevatedButton.icon(
                          onPressed: _stockMaterials,
                          icon: const Icon(Icons.warehouse),
                          label: const Text('Naskladniť materiály'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else if (_selectedRecipe != null && _quantityController.text.isNotEmpty) ...[
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Zadajte množstvo pre výpočet materiálov',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _quantityController.clear();
                      _calculateMaterials();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Vymazať'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _requiredMaterials.isNotEmpty ? _createBatch : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Vytvoriť šaržu'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


