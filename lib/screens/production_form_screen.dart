import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/production_type.dart';
import '../models/material.dart' as material_model;

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
      if (mounted) {
        setState(() {
          _productionTypes = types;
          _materials = materials;
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
      setState(() {
        _selectedMaterials = List<Map<String, dynamic>>.from(result['materials']);
      });
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
          const SnackBar(content: Text('Výroba bola vytvorená')),
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
                        _quantity = qty;
                        if (_useRecipe && _selectedRecipe != null) {
                          _calculateMaterialsFromRecipe();
                        }
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
                    const Text(
                      'Použité materiály:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedMaterials.asMap().entries.map((entry) {
                      final index = entry.key;
                      final material = entry.value;
                      final materialName = _materials
                          .firstWhere((m) => m.id == material['materialId'] as String)
                          .name;
                      final materialUnit = _materials
                          .firstWhere((m) => m.id == material['materialId'] as String)
                          .unit;
                      return Card(
                        child: ListTile(
                          title: Text(materialName),
                          subtitle: Text('${material['quantity']} $materialUnit'),
                          trailing: !_useRecipe
                              ? IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeMaterial(index),
                                )
                              : null,
                        ),
                      );
                    }),
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
