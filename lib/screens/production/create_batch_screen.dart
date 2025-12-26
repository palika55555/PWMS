import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class CreateBatchScreen extends StatefulWidget {
  final Recipe? preSelectedRecipe;
  final int? preFilledQuantity;
  
  const CreateBatchScreen({
    super.key,
    this.preSelectedRecipe,
    this.preFilledQuantity,
  });

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  Recipe? _selectedRecipe;
  DateTime _productionDate = DateTime.now();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _dryingDaysController = TextEditingController(text: '7'); // Default 7 days
  final _temperatureController = TextEditingController();
  final _humidityController = TextEditingController();
  List<Recipe> _recipes = [];
  List<Map<String, dynamic>> _requiredMaterials = [];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final recipes = await dbProvider.getRecipes();
    setState(() {
      _recipes = recipes;
      if (widget.preSelectedRecipe != null) {
        // Nájdeme zodpovedajúci Recipe v liste podľa ID (aby sme použili rovnakú inštanciu)
        final matchingRecipe = recipes.firstWhere(
          (r) => r.id == widget.preSelectedRecipe!.id,
          orElse: () => widget.preSelectedRecipe!,
        );
        _selectedRecipe = matchingRecipe;
      } else if (recipes.isNotEmpty) {
        _selectedRecipe = recipes.first;
      } else {
        _selectedRecipe = null;
      }
      if (widget.preFilledQuantity != null) {
        _quantityController.text = widget.preFilledQuantity.toString();
      }
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
    final allMaterials = await dbProvider.getMaterials();
    
    final List<Map<String, dynamic>> materials = [];
    
    // Add cement
    if (_selectedRecipe!.cementAmount > 0) {
      final requiredAmount = _selectedRecipe!.cementAmount * quantity;
      final cementMaterial = allMaterials.firstWhere(
        (m) => m.type == 'cement',
        orElse: () => material_model.Material(
          name: 'Cement',
          type: 'cement',
          unit: 'kg',
          currentStock: 0,
          minStock: 0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      materials.add({
        'name': 'Cement',
        'amount': requiredAmount,
        'unit': 'kg',
        'currentStock': cementMaterial.currentStock,
        'materialId': cementMaterial.id,
      });
    }
    
    // Add water
    if (_selectedRecipe!.waterAmount > 0) {
      final requiredAmount = _selectedRecipe!.waterAmount * quantity;
      final waterMaterial = allMaterials.firstWhere(
        (m) => m.type == 'water',
        orElse: () => material_model.Material(
          name: 'Voda',
          type: 'water',
          unit: 'l',
          currentStock: 0,
          minStock: 0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      materials.add({
        'name': 'Voda',
        'amount': requiredAmount,
        'unit': 'l',
        'currentStock': waterMaterial.currentStock,
        'materialId': waterMaterial.id,
      });
    }
    
    // Add plasticizer
    if (_selectedRecipe!.plasticizerAmount != null && _selectedRecipe!.plasticizerAmount! > 0) {
      final requiredAmount = _selectedRecipe!.plasticizerAmount! * quantity;
      final plasticizerMaterial = allMaterials.firstWhere(
        (m) => m.type == 'plasticizer',
        orElse: () => material_model.Material(
          name: 'Plastifikátor',
          type: 'plasticizer',
          unit: 'l',
          currentStock: 0,
          minStock: 0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      materials.add({
        'name': 'Plastifikátor',
        'amount': requiredAmount,
        'unit': 'l',
        'currentStock': plasticizerMaterial.currentStock,
        'materialId': plasticizerMaterial.id,
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
          'currentStock': material.currentStock,
          'materialId': material.id,
        });
      }
    }
    
    setState(() {
      _requiredMaterials = materials;
    });
  }

  Future<void> _createBatch() async {
    if (!_formKey.currentState!.validate() || _selectedRecipe == null) {
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    // Generate batch number
    final batchNumber = 'BATCH-${DateFormat('yyyyMMdd').format(_productionDate)}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Calculate curing dates
    final dryingDays = _dryingDaysController.text.isNotEmpty
        ? int.tryParse(_dryingDaysController.text)
        : null;
    final curingStartDate = DateTime.now().toIso8601String();
    final curingEndDate = dryingDays != null
        ? DateTime.now().add(Duration(days: dryingDays)).toIso8601String()
        : null;

    final batch = Batch(
      batchNumber: batchNumber,
      recipeId: _selectedRecipe!.id!,
      productionDate: DateFormat('yyyy-MM-dd').format(_productionDate),
      quantity: int.parse(_quantityController.text),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      qualityStatus: 'pending',
      dryingDays: dryingDays,
      curingStartDate: curingStartDate,
      curingEndDate: curingEndDate,
      productionTemperature: _temperatureController.text.isNotEmpty
          ? double.tryParse(_temperatureController.text)
          : null,
      productionHumidity: _humidityController.text.isNotEmpty
          ? double.tryParse(_humidityController.text)
          : null,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    try {
      await dbProvider.insertBatch(batch);
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Šarža bola úspešne vytvorená'),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
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
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _dryingDaysController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // HEADER
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nová šarža',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Vytvorte novú výrobnú šaržu',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // BODY
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Recipe selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Receptúra',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Recipe>(
                            value: _selectedRecipe != null && _recipes.any((r) => r.id == _selectedRecipe!.id)
                                ? _selectedRecipe
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Vyberte receptúru *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            items: _recipes.map((recipe) {
                              return DropdownMenuItem(
                                value: recipe,
                                child: Text(recipe.name),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Production date
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: const Text(
                        'Dátum výroby',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy', 'sk_SK').format(_productionDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _productionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _productionDate = date;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quantity
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.numbers, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Množstvo',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Množstvo (ks) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory_2),
                              helperText: 'Zadajte počet kusov na výrobu',
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
                  
                  // Drying and curing section
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.water_drop, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Sušenie a zrenie',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dryingDaysController,
                            decoration: const InputDecoration(
                              labelText: 'Doba sušenia (dni) *',
                              border: OutlineInputBorder(),
                              helperText: 'Odporúčané: 7-28 dní (štandardne 7 dní)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Zadajte dobu sušenia';
                              }
                              final days = int.tryParse(value);
                              if (days == null || days <= 0) {
                                return 'Zadajte platný počet dní';
                              }
                              if (days > 365) {
                                return 'Doba sušenia nemôže byť viac ako 365 dní';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _temperatureController,
                                  decoration: const InputDecoration(
                                    labelText: 'Teplota pri výrobe (°C)',
                                    border: OutlineInputBorder(),
                                    helperText: 'Voliteľné',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _humidityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Vlhkosť pri výrobe (%)',
                                    border: OutlineInputBorder(),
                                    helperText: 'Voliteľné',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.green.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tip: Optimálna teplota: 15-25°C, Vlhkosť: 50-70%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade900,
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
                  
                  // Required materials preview with stock status
                  if (_requiredMaterials.isNotEmpty)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.calculate, color: Colors.blue.shade700, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Potrebné materiály',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Aktuálny stav skladu',
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._requiredMaterials.map((m) {
                              final requiredAmount = (m['amount'] as num).toDouble();
                              final currentStock = (m['currentStock'] as num?)?.toDouble() ?? 0.0;
                              final isSufficient = currentStock >= requiredAmount;
                              final stockPercentage = currentStock > 0 
                                  ? (currentStock / requiredAmount * 100).clamp(0.0, 100.0)
                                  : 0.0;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSufficient ? Colors.green.shade200 : Colors.orange.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSufficient ? Colors.green.shade100 : Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSufficient ? Icons.check_circle : Icons.warning,
                                                size: 14,
                                                color: isSufficient ? Colors.green.shade700 : Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSufficient ? 'Dostupné' : 'Nedostatočné',
                                                style: TextStyle(
                                                  color: isSufficient ? Colors.green.shade700 : Colors.orange.shade700,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Potrebné:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${requiredAmount.toStringAsFixed(2)} ${m['unit']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Na sklade:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${currentStock.toStringAsFixed(2)} ${m['unit']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isSufficient ? Colors.green.shade700 : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: stockPercentage / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isSufficient ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${stockPercentage.toStringAsFixed(0)}% pokrytie',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  if (_requiredMaterials.isNotEmpty)
                    const SizedBox(height: 16),
            
                  // Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Poznámky',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Poznámky (voliteľné)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.edit_note),
                              helperText: 'Pridajte ďalšie informácie o šarži',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // FOOTER
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _createBatch,
                  icon: const Icon(Icons.check),
                  label: const Text('Vytvoriť šaržu'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


