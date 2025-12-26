import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedProductType = 'tvarnice';
  final _cementController = TextEditingController();
  final _waterController = TextEditingController();
  final _plasticizerController = TextEditingController();
  final _mixerCapacityController = TextEditingController();
  final _productsPerMixerController = TextEditingController();
  
  List<material_model.Material> _materials = [];
  List<Map<String, dynamic>> _aggregates = []; // {material, fraction, amount}
  bool _loading = true;
  
  // Calculated values per product
  Map<String, double> _materialsPerProduct = {};

  final List<String> _productTypes = [
    'tvarnice',
    'dlazba',
    'obrubniky',
    'iné',
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    setState(() {
      _materials = materials.where((m) => m.type == 'aggregate').toList();
      _loading = false;
    });
  }

  void _calculateWCRatio() {
    // Calculate water/cement ratio if needed in the future
    // final water = double.tryParse(_waterController.text) ?? 0;
    // final cement = double.tryParse(_cementController.text) ?? 0;
    // if (cement > 0) {
    //   final ratio = water / cement;
    // }
  }

  Future<void> _addAggregate() async {
    if (_materials.isEmpty) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Najprv vytvorte materiál typu "Štrk" v skladovom hospodárstve'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
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
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddAggregateDialog(materials: _materials),
    );

    if (result != null) {
      setState(() {
        _aggregates.add(result);
      });
    }
  }

  void _removeAggregate(int index) {
    setState(() {
      _aggregates.removeAt(index);
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final cementAmount = double.parse(_cementController.text);
    final waterAmount = double.parse(_waterController.text);
    final plasticizerAmount = _plasticizerController.text.isNotEmpty
        ? double.tryParse(_plasticizerController.text)
        : null;
    final wcRatio = cementAmount > 0 ? waterAmount / cementAmount : null;
    final mixerCapacity = _mixerCapacityController.text.isNotEmpty
        ? double.tryParse(_mixerCapacityController.text)
        : null;
    final productsPerMixer = _productsPerMixerController.text.isNotEmpty
        ? int.tryParse(_productsPerMixerController.text)
        : null;

    final recipe = Recipe(
      name: _nameController.text,
      productType: _selectedProductType,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      cementAmount: cementAmount,
      waterAmount: waterAmount,
      plasticizerAmount: plasticizerAmount,
      wcRatio: wcRatio,
      mixerCapacity: mixerCapacity,
      productsPerMixer: productsPerMixer,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    try {
      final recipeId = await dbProvider.insertRecipe(recipe);
      
      // Save aggregates
      for (final aggregate in _aggregates) {
        await dbProvider.insertRecipeAggregate(
          recipeId,
          aggregate['material_id'] as int,
          aggregate['fraction_id'] as int?,
          aggregate['amount'] as double,
        );
      }

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Receptúra bola úspešne vytvorená'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cementController.dispose();
    _waterController.dispose();
    _plasticizerController.dispose();
    _mixerCapacityController.dispose();
    _productsPerMixerController.dispose();
    super.dispose();
  }
  
  void _calculateMaterialsPerProduct() {
    final productsPerMixer = int.tryParse(_productsPerMixerController.text);
    final cement = double.tryParse(_cementController.text) ?? 0;
    final water = double.tryParse(_waterController.text) ?? 0;
    final plasticizer = double.tryParse(_plasticizerController.text) ?? 0;
    
    if (productsPerMixer != null && productsPerMixer > 0) {
      setState(() {
        _materialsPerProduct = {
          'cement': cement / productsPerMixer,
          'water': water / productsPerMixer,
          'plasticizer': plasticizer / productsPerMixer,
        };
        
        // Calculate aggregates per product
        for (final aggregate in _aggregates) {
          final amount = aggregate['amount'] as double;
          final materialId = aggregate['material_id'] as int;
          _materialsPerProduct['aggregate_$materialId'] = amount / productsPerMixer;
        }
      });
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
                            'Nová receptúra',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Vytvorte novú výrobnú receptúru',
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
                  // Name
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.label, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Základné informácie',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Názov receptúry *',
                              border: OutlineInputBorder(),
                              hintText: 'Napr. Tvárnice 20cm',
                              prefixIcon: Icon(Icons.edit),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Zadajte názov';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedProductType,
                            decoration: const InputDecoration(
                              labelText: 'Typ produktu *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
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
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Popis',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                              helperText: 'Poznámky, odporúčania alebo špeciálne požiadavky',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
            // Reference recipes info
            Card(
              color: Colors.amber.shade50,
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Referenčné receptúry nájdete v súbore RECIPES_REFERENCE.md',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Basic materials section
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Základné materiály',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Cement
                    TextFormField(
                      controller: _cementController,
                      decoration: const InputDecoration(
                        labelText: 'Cement (kg) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.construction),
                        helperText: 'Odporúčané: 350-450 kg/m³ betónu',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateWCRatio(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zadajte množstvo cementu';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Zadajte platné množstvo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Water
                    TextFormField(
                      controller: _waterController,
                      decoration: const InputDecoration(
                        labelText: 'Voda (l) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop),
                        helperText: 'Pomer V/C: 0,4-0,6 (voda/cement)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateWCRatio(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Zadajte množstvo vody';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Zadajte platné množstvo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Plasticizer
                    TextFormField(
                      controller: _plasticizerController,
                      decoration: const InputDecoration(
                        labelText: 'Plastifikátor (l)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.science),
                        helperText: 'Voliteľné',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    
                    // Mixer capacity and products per mixer
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mixerCapacityController,
                            decoration: const InputDecoration(
                              labelText: 'Kapacita miešačky (l)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.blender),
                              helperText: 'Voliteľné - kapacita miešačky v litroch',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateMaterialsPerProduct(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _productsPerMixerController,
                            decoration: const InputDecoration(
                              labelText: 'Počet produktov z miešačky',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                              helperText: 'Voliteľné - koľko produktov vyjde z jednej miešačky',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateMaterialsPerProduct(),
                          ),
                        ),
                      ],
                    ),
                    // Show calculated materials per product
                    if (_materialsPerProduct.isNotEmpty && _productsPerMixerController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calculate, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Množstvo materiálov na 1 produkt:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_materialsPerProduct['cement'] != null)
                              Text(
                                'Cement: ${_materialsPerProduct['cement']!.toStringAsFixed(2)} kg',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                            if (_materialsPerProduct['water'] != null)
                              Text(
                                'Voda: ${_materialsPerProduct['water']!.toStringAsFixed(2)} l',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                            if (_materialsPerProduct['plasticizer'] != null && _materialsPerProduct['plasticizer']! > 0)
                              Text(
                                'Plastifikátor: ${_materialsPerProduct['plasticizer']!.toStringAsFixed(2)} l',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                            ..._aggregates.map((aggregate) {
                              final materialId = aggregate['material_id'] as int;
                              final material = _materials.firstWhere((m) => m.id == materialId);
                              final fraction = aggregate['fraction'] as Map<String, dynamic>?;
                              final amountPerProduct = _materialsPerProduct['aggregate_$materialId'];
                              
                              if (amountPerProduct == null) return const SizedBox.shrink();
                              
                              return Text(
                                '${fraction != null ? '${material.name} - ${fraction['fraction_name']}' : material.name}: ${amountPerProduct.toStringAsFixed(2)} ${material.unit}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Aggregates section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Agregáty',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addAggregate,
                          icon: const Icon(Icons.add),
                          label: const Text('Pridať agregát'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Info about fractions
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Odporúčané frakcie: 0-4mm (piesok), 4-8mm, 8-16mm',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_aggregates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Žiadne agregáty',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._aggregates.asMap().entries.map((entry) {
                        final index = entry.key;
                        final aggregate = entry.value;
                        final material = _materials.firstWhere(
                          (m) => m.id == aggregate['material_id'],
                        );
                        final fraction = aggregate['fraction'] as Map<String, dynamic>?;
                        final amount = aggregate['amount'] as double;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.grey.shade50,
                          child: ListTile(
                            title: Text(
                              fraction != null
                                  ? '${material.name} - ${fraction['fraction_name']}'
                                  : material.name,
                            ),
                            subtitle: Text('${amount.toStringAsFixed(2)} ${material.unit}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeAggregate(index),
                            ),
                          ),
                        );
                      }).toList(),
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
                  onPressed: _saveRecipe,
                  icon: const Icon(Icons.save),
                  label: const Text('Uložiť receptúru'),
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

class _AddAggregateDialog extends StatefulWidget {
  final List<material_model.Material> materials;

  const _AddAggregateDialog({required this.materials});

  @override
  State<_AddAggregateDialog> createState() => _AddAggregateDialogState();
}

class _AddAggregateDialogState extends State<_AddAggregateDialog> {
  final _formKey = GlobalKey<FormState>();
  material_model.Material? _selectedMaterial;
  Map<String, dynamic>? _selectedFraction;
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> _fractions = [];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadFractions() async {
    if (_selectedMaterial == null) {
      setState(() {
        _fractions = [];
      });
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final db = await dbProvider.getDatabase();
    final fractionMaps = await db.query(
      'aggregate_fractions',
      where: 'material_id = ?',
      whereArgs: [_selectedMaterial!.id],
    );

    setState(() {
      _fractions = fractionMaps;
      _selectedFraction = null;
    });
  }

  void _add() {
    if (!_formKey.currentState!.validate() || _selectedMaterial == null) {
      return;
    }

    Navigator.pop(context, {
      'material_id': _selectedMaterial!.id,
      'fraction': _selectedFraction,
      'fraction_id': _selectedFraction?['id'],
      'amount': double.parse(_amountController.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať agregát'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.materials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Žiadne materiály typu "Štrk" nie sú k dispozícii. Vytvorte ich v skladovom hospodárstve.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  DropdownButtonFormField<material_model.Material>(
                    value: _selectedMaterial,
                    decoration: const InputDecoration(
                      labelText: 'Materiál *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    isExpanded: true,
                    items: widget.materials.map((material) {
                      return DropdownMenuItem<material_model.Material>(
                        value: material,
                        child: Text(
                          material.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (material) {
                      setState(() {
                        _selectedMaterial = material;
                      });
                      _loadFractions();
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Vyberte materiál';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              
              if (widget.materials.isNotEmpty && _fractions.isNotEmpty) ...[
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedFraction,
                  decoration: const InputDecoration(
                    labelText: 'Frakcia',
                    border: OutlineInputBorder(),
                    helperText: 'Voliteľné',
                  ),
                  items: _fractions.map((fraction) {
                    return DropdownMenuItem(
                      value: fraction,
                      child: Text(
                        '${fraction['fraction_name']} (${fraction['size_min']}-${fraction['size_max']} mm)',
                      ),
                    );
                  }).toList(),
                  onChanged: (fraction) {
                    setState(() {
                      _selectedFraction = fraction;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              if (widget.materials.isNotEmpty)
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Množstvo${_selectedMaterial != null ? ' (${_selectedMaterial!.unit})' : ''} *',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadajte množstvo';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Zadajte platné množstvo';
                  }
                  return null;
                },
              ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: _add,
          child: const Text('Pridať'),
        ),
      ],
    );
  }
}


