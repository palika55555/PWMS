import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/production_type.dart';
import '../models/material.dart' as material_model;

class RecipeFormScreen extends StatefulWidget {
  final dynamic recipe;

  const RecipeFormScreen({super.key, this.recipe});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  ProductionType? _selectedType;
  List<ProductionType> _productionTypes = [];
  List<material_model.Material> _materials = [];
  List<Map<String, dynamic>> _recipeMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _nameController.text = widget.recipe['name'] ?? '';
      _descriptionController.text = widget.recipe['description'] ?? '';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final types = await apiService.getProductionTypes();
      final materials = await apiService.getMaterials();
      
      if (widget.recipe != null && widget.recipe['production_type_id'] != null) {
        final selectedType = types.firstWhere(
          (t) => t.id == widget.recipe['production_type_id'],
          orElse: () => types.first,
        );
        _selectedType = selectedType;
      }
      
      setState(() {
        _productionTypes = types;
        _materials = materials;
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

  void _addMaterial() {
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najprv musíte vytvoriť materiály')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _RecipeMaterialDialog(
        materials: _materials,
        onAdd: (materialId, quantityPerUnit) {
          setState(() {
            _recipeMaterials.add({
              'materialId': materialId,
              'quantityPerUnit': quantityPerUnit,
            });
          });
        },
      ),
    );
  }

  void _removeMaterial(int index) {
    setState(() {
      _recipeMaterials.removeAt(index);
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
    if (_recipeMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pridajte aspoň jeden materiál do receptu')),
      );
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (widget.recipe == null) {
        await apiService.createRecipe(
          productionTypeId: _selectedType!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          materials: _recipeMaterials,
        );
      } else {
        await apiService.updateRecipe(
          id: widget.recipe['id'],
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          materials: _recipeMaterials,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.recipe == null ? 'Recept bol vytvorený' : 'Recept bol aktualizovaný')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Nový recept' : 'Upraviť recept'),
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
                      setState(() => _selectedType = value);
                    },
                    validator: (value) {
                      if (value == null) return 'Vyberte typ výroby';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Názov receptu',
                      border: OutlineInputBorder(),
                      hintText: 'napr. Recept pre tvárnice C25/30',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Zadajte názov receptu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Popis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Materiály (na 1 jednotku výroby):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addMaterial,
                    icon: const Icon(Icons.add),
                    label: const Text('Pridať materiál'),
                  ),
                  const SizedBox(height: 16),
                  if (_recipeMaterials.isNotEmpty) ...[
                    ..._recipeMaterials.asMap().entries.map((entry) {
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
                          subtitle: Text('${material['quantityPerUnit']} $materialUnit / jednotka'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeMaterial(index),
                          ),
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
                    child: Text(widget.recipe == null ? 'Vytvoriť recept' : 'Uložiť zmeny'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _RecipeMaterialDialog extends StatefulWidget {
  final List<material_model.Material> materials;
  final Function(String materialId, double quantityPerUnit) onAdd;

  const _RecipeMaterialDialog({
    required this.materials,
    required this.onAdd,
  });

  @override
  State<_RecipeMaterialDialog> createState() => _RecipeMaterialDialogState();
}

class _RecipeMaterialDialogState extends State<_RecipeMaterialDialog> {
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať materiál do receptu'),
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
              labelText: 'Množstvo na 1 jednotku výroby',
              border: OutlineInputBorder(),
              hintText: 'napr. 50 pre 50 kg cementu na 1 m²',
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

