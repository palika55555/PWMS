import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/production_type.dart';
import '../models/material.dart' as material_model;
import '../models/warehouse.dart';

class ProductionFormScreen extends StatefulWidget {
  const ProductionFormScreen({super.key});

  @override
  State<ProductionFormScreen> createState() => _ProductionFormScreenState();
}

class _ProductionFormScreenState extends State<ProductionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ProductionType? _selectedType;
  dynamic _selectedRecipe;
  double _quantity = 0;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _productionDate = DateTime.now();

  List<ProductionType> _productionTypes = [];
  List<material_model.Material> _materials = [];
  List<Warehouse> _warehouse = [];
  List<dynamic> _recipes = [];
  List<Map<String, dynamic>> _selectedMaterials = [];
  bool _isLoading = true;
  bool _useRecipe = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final types = await apiService.getProductionTypes();
      final materials = await apiService.getMaterials();
      final warehouse = await apiService.getWarehouse();
      if (mounted) {
        setState(() {
          _productionTypes = types;
          _materials = materials;
          _warehouse = warehouse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: $e')),
        );
      }
    }
  }

  double _getAvailableQuantity(String materialId) {
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

  bool _hasEnoughMaterial(String materialId, double required) {
    return _getAvailableQuantity(materialId) >= required;
  }

  Future<void> _loadRecipes() async {
    if (_selectedType == null) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final recipes = await apiService.getRecipesByProductionType(_selectedType!.id);
      setState(() {
        _recipes = recipes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní receptov: $e')),
        );
      }
    }
  }

  Future<void> _calculateMaterialsFromRecipe() async {
    if (_selectedRecipe == null || _quantity <= 0) {
      setState(() {
        _selectedMaterials = [];
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.calculateRecipeMaterials(
        _selectedRecipe['id'],
        _quantity,
      );
      
      if (mounted) {
        setState(() {
          _selectedMaterials = List<Map<String, dynamic>>.from(result['materials']);
        });
        
        // Zobrazíme informáciu o automatickom výpočte
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Materiály boli automaticky vypočítané pre ${_quantity.toStringAsFixed(2)} jednotiek',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri výpočte materiálov: $e')),
        );
      }
    }
  }

  void _addMaterial() {
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najprv musíte vytvoriť materiály')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _MaterialDialog(
        materials: _materials,
        onAdd: (materialId, quantity) {
          setState(() {
            _selectedMaterials.add({
              'materialId': materialId,
              'quantity': quantity,
            });
          });
        },
      ),
    );
  }

  void _removeMaterial(int index) {
    setState(() {
      _selectedMaterials.removeAt(index);
    });
  }

  void _editMaterialFromRecipe(int index) {
    final material = _selectedMaterials[index];
    final materialObj = _materials.firstWhere(
      (m) => m.id == material['materialId'] as String,
    );

    final quantityController = TextEditingController(
      text: material['quantity'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upraviť ${materialObj.name}'),
        content: TextFormField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Množstvo',
            suffixText: materialObj.unit,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = double.tryParse(quantityController.text);
              if (newQuantity != null && newQuantity > 0) {
                setState(() {
                  _selectedMaterials[index] = {
                    'materialId': material['materialId'],
                    'quantity': newQuantity,
                  };
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Uložiť'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte typ výroby')),
      );
      return;
    }
    if (_selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pridajte materiály alebo použite recept')),
      );
      return;
    }

    // Kontrola dostupnosti materiálov
    final missingMaterials = <String>[];
    for (final material in _selectedMaterials) {
      final materialId = material['materialId'] as String;
      final requiredQuantity = material['quantity'] as double;
      if (!_hasEnoughMaterial(materialId, requiredQuantity)) {
        final materialName = _materials
            .firstWhere((m) => m.id == materialId)
            .name;
        missingMaterials.add(materialName);
      }
    }

    if (missingMaterials.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nedostatok materiálov'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nasledujúce materiály nie sú dostupné v dostatočnom množstve:'),
              const SizedBox(height: 8),
              ...missingMaterials.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
              const SizedBox(height: 16),
              const Text('Chcete pokračovať aj tak?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Pokračovať'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createProduction(
        productionTypeId: _selectedType!.id,
        quantity: _quantity,
        materials: _selectedMaterials,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        productionDate: _productionDate,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Výroba bola vytvorená'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri vytváraní: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nová výroba'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  DropdownButtonFormField<ProductionType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Typ výroby',
                      border: OutlineInputBorder(),
                    ),
                    items: _productionTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value;
                        _selectedRecipe = null;
                        _selectedMaterials = [];
                        _useRecipe = false;
                      });
                      if (value != null) {
                        _loadRecipes();
                      }
                    },
                    validator: (value) {
                      if (value == null) return 'Vyberte typ výroby';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Použiť recept'),
                    value: _useRecipe,
                    onChanged: (value) {
                      setState(() {
                        _useRecipe = value ?? false;
                        if (!_useRecipe) {
                          _selectedRecipe = null;
                          _selectedMaterials = [];
                        }
                      });
                      if (_useRecipe && _selectedType != null) {
                        _loadRecipes();
                      }
                    },
                  ),
                  if (_useRecipe && _selectedType != null) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<dynamic>(
                      value: _selectedRecipe,
                      decoration: const InputDecoration(
                        labelText: 'Recept',
                        border: OutlineInputBorder(),
                      ),
                      items: _recipes.map((recipe) {
                        return DropdownMenuItem(
                          value: recipe,
                          child: Text(recipe['name'] ?? 'Neznámy recept'),
                        );
                      }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRecipe = value;
                      });
                      if (value != null && _quantity > 0) {
                        _calculateMaterialsFromRecipe();
                      } else if (value == null) {
                        setState(() {
                          _selectedMaterials = [];
                        });
                      }
                    },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Množstvo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Zadajte množstvo';
                      }
                      final qty = double.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'Množstvo musí byť kladné číslo';
                      }
                      _quantity = qty;
                      return null;
                    },
                    onChanged: (value) {
                      final qty = double.tryParse(value);
                      if (qty != null && qty > 0) {
                        setState(() {
                          _quantity = qty;
                        });
                        if (_useRecipe && _selectedRecipe != null) {
                          _calculateMaterialsFromRecipe();
                        }
                      } else {
                        setState(() {
                          _quantity = 0;
                          if (_useRecipe) {
                            _selectedMaterials = [];
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Dátum výroby'),
                    subtitle: Text(
                      '${_productionDate.day}.${_productionDate.month}.${_productionDate.year} ${_productionDate.hour}:${_productionDate.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _productionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_productionDate),
                        );
                        if (time != null) {
                          setState(() {
                            _productionDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Poznámky',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  if (!_useRecipe) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addMaterial,
                            icon: const Icon(Icons.add),
                            label: const Text('Pridať materiál'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedMaterials.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Použité materiály:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_useRecipe)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _useRecipe = false;
                                _selectedRecipe = null;
                              });
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Upraviť'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._selectedMaterials.asMap().entries.map((entry) {
                      final index = entry.key;
                      final material = entry.value;
                      final materialId = material['materialId'] as String;
                      final requiredQuantity = material['quantity'] as double;
                      final materialName = _materials
                          .firstWhere((m) => m.id == materialId)
                          .name;
                      final materialUnit = _materials
                          .firstWhere((m) => m.id == materialId)
                          .unit;
                      final availableQuantity = _getAvailableQuantity(materialId);
                      final hasEnough = _hasEnoughMaterial(materialId, requiredQuantity);
                      
                      return Card(
                        color: hasEnough ? null : Colors.red.shade50,
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: hasEnough
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              hasEnough ? Icons.check_circle : Icons.warning,
                              color: hasEnough ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(materialName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _useRecipe
                                  ? Text(
                                      'Potrebné: ${requiredQuantity.toStringAsFixed(2)} $materialUnit (z receptúry)',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : Text(
                                      'Potrebné: ${requiredQuantity.toStringAsFixed(2)} $materialUnit',
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                'Dostupné: ${availableQuantity.toStringAsFixed(2)} $materialUnit',
                                style: TextStyle(
                                  color: hasEnough
                                      ? Colors.grey[600]
                                      : Colors.red[700],
                                  fontSize: 12,
                                  fontWeight: hasEnough
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              if (!hasEnough)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Nedostatok: ${(requiredQuantity - availableQuantity).toStringAsFixed(2)} $materialUnit',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: !_useRecipe
                              ? IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeMaterial(index),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editMaterialFromRecipe(index),
                                  tooltip: 'Upraviť množstvo',
                                ),
                        ),
                      );
                    }),
                    if (_useRecipe && _selectedMaterials.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Materiály boli automaticky vypočítané z receptúry. Môžete ich upraviť kliknutím na ikonu edit.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Vytvoriť výrobu'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class _MaterialDialog extends StatefulWidget {
  final List<material_model.Material> materials;
  final Function(String materialId, double quantity) onAdd;

  const _MaterialDialog({
    required this.materials,
    required this.onAdd,
  });

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať materiál'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<material_model.Material>(
            value: _selectedMaterial,
            decoration: const InputDecoration(
              labelText: 'Materiál',
              border: OutlineInputBorder(),
            ),
            items: widget.materials.map((material) {
              return DropdownMenuItem<material_model.Material>(
                value: material,
                child: Text('${material.name} (${material.unit})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedMaterial = value);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Množstvo',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedMaterial != null &&
                _quantityController.text.isNotEmpty) {
              final quantity = double.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                widget.onAdd(_selectedMaterial!.id, quantity);
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Pridať'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
