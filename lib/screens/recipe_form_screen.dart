import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/production_type.dart';
import '../models/material.dart' as material_model;

class RecipeFormScreen extends StatefulWidget {
  final dynamic recipe;
  final String? productionTypeId;

  const RecipeFormScreen({super.key, this.recipe, this.productionTypeId});

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
  
  // Pre vytvorenie receptu z miešačky
  bool _useMixerMode = false;
  final _piecesFromMixerController = TextEditingController();
  List<Map<String, dynamic>> _mixerMaterials = []; // Materiály pre jednu miešačku

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
      
      List<Map<String, dynamic>> recipeMaterials = [];
      
      // Načítanie materiálov receptu
      if (widget.recipe != null) {
        if (widget.recipe['materials'] != null && 
            (widget.recipe['materials'] as List).isNotEmpty) {
          recipeMaterials = List<Map<String, dynamic>>.from(
            (widget.recipe['materials'] as List).map((m) => {
              'materialId': m['material_id'] ?? m['materialId'],
              'quantityPerUnit': ((m['quantity_per_unit'] ?? m['quantityPerUnit']) as num).toDouble(),
            })
          );
        } else if (widget.recipe['id'] != null) {
          // Ak recept nemá materiály, skúsme ich načítať z API
          try {
            final recipeDetail = await apiService.getRecipeById(widget.recipe['id']);
            if (recipeDetail['materials'] != null && 
                (recipeDetail['materials'] as List).isNotEmpty) {
              recipeMaterials = List<Map<String, dynamic>>.from(
                (recipeDetail['materials'] as List).map((m) => {
                  'materialId': m['material_id'] ?? m['materialId'],
                  'quantityPerUnit': ((m['quantity_per_unit'] ?? m['quantityPerUnit']) as num).toDouble(),
                })
              );
            }
          } catch (e) {
            debugPrint('Nepodarilo sa načítať materiály receptu: $e');
          }
        }
      }
      
      // Najprv nastavíme zoznamy v setState
      setState(() {
        _productionTypes = types;
        _materials = materials;
        _recipeMaterials = recipeMaterials;
        _isLoading = false;
        
        // Potom nastavíme _selectedType z inštancií v _productionTypes
        // Ak je poskytnutý productionTypeId, automaticky ho vyberieme
        if (widget.productionTypeId != null) {
          _selectedType = _productionTypes.firstWhere(
            (t) => t.id == widget.productionTypeId,
            orElse: () => _productionTypes.isNotEmpty ? _productionTypes.first : _productionTypes.first,
          );
        } else if (widget.recipe != null) {
          if (widget.recipe['production_type_id'] != null) {
            _selectedType = _productionTypes.firstWhere(
              (t) => t.id == widget.recipe['production_type_id'],
              orElse: () => _productionTypes.isNotEmpty ? _productionTypes.first : _productionTypes.first,
            );
          }
        }
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

  void _addMixerMaterial() {
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najprv musíte vytvoriť materiály')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _MixerMaterialDialog(
        materials: _materials,
        onAdd: (materialId, quantityForMixer) {
          setState(() {
            _mixerMaterials.add({
              'materialId': materialId,
              'quantityForMixer': quantityForMixer,
            });
            if (_piecesFromMixerController.text.isNotEmpty) {
              _calculateMaterialsPerPiece();
            }
          });
        },
      ),
    );
  }

  void _editMixerMaterial(int index) {
    final material = _mixerMaterials[index];
    final materialObj = _materials.firstWhere(
      (m) => m.id == material['materialId'] as String,
    );

    final quantityController = TextEditingController(
      text: material['quantityForMixer'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upraviť ${materialObj.name}'),
        content: TextFormField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Množstvo pre miešačku',
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
                  _mixerMaterials[index] = {
                    'materialId': material['materialId'],
                    'quantityForMixer': newQuantity,
                  };
                  if (_piecesFromMixerController.text.isNotEmpty) {
                    _calculateMaterialsPerPiece();
                  }
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

  void _removeMixerMaterial(int index) {
    setState(() {
      _mixerMaterials.removeAt(index);
      if (_piecesFromMixerController.text.isNotEmpty) {
        _calculateMaterialsPerPiece();
      }
    });
  }

  void _calculateMaterialsPerPiece() {
    final pieces = double.tryParse(_piecesFromMixerController.text);
    if (pieces == null || pieces <= 0) {
      setState(() {
        _recipeMaterials = [];
      });
      return;
    }

    setState(() {
      _recipeMaterials = _mixerMaterials.map((mixerMat) {
        final quantityForMixer = mixerMat['quantityForMixer'] as double;
        final quantityPerUnit = quantityForMixer / pieces;
        return {
          'materialId': mixerMat['materialId'],
          'quantityPerUnit': quantityPerUnit,
        };
      }).toList();
    });
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
    // Validácia pre mixer mode
    if (_useMixerMode) {
      if (_piecesFromMixerController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zadajte počet kusov z jednej miešačky'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_mixerMaterials.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pridajte aspoň jeden materiál do miešačky'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    if (_recipeMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pridajte aspoň jeden materiál do receptu'),
          backgroundColor: Colors.orange,
        ),
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
        Navigator.pop(context, true); // Vrátime true, aby production_form_screen vedel, že recept bol vytvorený
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.recipe == null ? 'Recept bol vytvorený' : 'Recept bol aktualizovaný'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
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

  void _editMaterial(int index) {
    final material = _recipeMaterials[index];
    final materialObj = _materials.firstWhere(
      (m) => m.id == material['materialId'] as String,
    );

    final quantityController = TextEditingController(
      text: material['quantityPerUnit'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upraviť ${materialObj.name}'),
        content: TextFormField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Množstvo na 1 jednotku',
            suffixText: materialObj.unit,
            border: const OutlineInputBorder(),
            hintText: 'napr. 50 pre 50 kg na 1 m²',
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
                  _recipeMaterials[index] = {
                    'materialId': material['materialId'],
                    'quantityPerUnit': newQuantity,
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
                  // Typ výroby
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Základné informácie',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ProductionType>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: 'Typ výroby *',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.inventory_2),
                              filled: widget.productionTypeId != null,
                              fillColor: widget.productionTypeId != null 
                                  ? Colors.blue.shade50 
                                  : null,
                              helperText: widget.productionTypeId != null
                                  ? 'Receptúra je napárovaná na tento typ výroby'
                                  : null,
                            ),
                            items: _productionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name),
                              );
                            }).toList(),
                            onChanged: widget.productionTypeId != null 
                                ? null // Disabled, ak je poskytnutý productionTypeId
                                : (value) {
                                    setState(() => _selectedType = value);
                                  },
                            validator: (value) {
                              if (value == null) return 'Vyberte typ výroby';
                              return null;
                            },
                          ),
                          if (widget.productionTypeId != null && _selectedType != null) ...[
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
                                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Táto receptúra bude napárovaná na typ výroby: ${_selectedType!.name}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Názov receptu *',
                              border: OutlineInputBorder(),
                              hintText: 'napr. Recept pre tvárnice C25/30',
                              prefixIcon: Icon(Icons.label),
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
                              hintText: 'Popis receptúry, pomery, poznámky...',
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Režim miešačky
                  if (widget.recipe == null) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.blender, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'Vytvorenie z miešačky',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vytvorte recept na základe množstva materiálov pre jednu miešačku a počtu kusov, ktoré sa z nej vyrobia.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Použiť režim miešačky'),
                              subtitle: const Text('Recept sa vytvorí na základe miešačky'),
                              value: _useMixerMode,
                              onChanged: (value) {
                                setState(() {
                                  _useMixerMode = value;
                                  if (value) {
                                    _recipeMaterials = [];
                                    _mixerMaterials = [];
                                  } else {
                                    _mixerMaterials = [];
                                  }
                                });
                              },
                            ),
                            if (_useMixerMode) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _piecesFromMixerController,
                                decoration: const InputDecoration(
                                  labelText: 'Počet kusov z jednej miešačky *',
                                  border: OutlineInputBorder(),
                                  hintText: 'napr. 50',
                                  prefixIcon: Icon(Icons.numbers),
                                  helperText: 'Koľko kusov sa vyrobí z jednej miešačky?',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (value.isNotEmpty && _mixerMaterials.isNotEmpty) {
                                    _calculateMaterialsPerPiece();
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addMixerMaterial,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Pridať materiál do miešačky'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                              if (_mixerMaterials.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                Text(
                                  'Materiály pre jednu miešačku:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._mixerMaterials.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final material = entry.value;
                                  final materialName = _materials
                                      .firstWhere(
                                        (m) => m.id == material['materialId'] as String,
                                      )
                                      .name;
                                  final materialUnit = _materials
                                      .firstWhere(
                                        (m) => m.id == material['materialId'] as String,
                                      )
                                      .unit;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: Colors.blue.shade50,
                                    child: ListTile(
                                      leading: Icon(Icons.inventory_2, color: Colors.blue.shade700),
                                      title: Text(materialName),
                                      subtitle: Text(
                                        '${material['quantityForMixer']} $materialUnit',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _editMixerMaterial(index),
                                            color: Colors.blue,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () => _removeMixerMaterial(index),
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                if (_piecesFromMixerController.text.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vypočítané množstvá na 1 kus:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._recipeMaterials.map((material) {
                                    final materialName = _materials
                                        .firstWhere(
                                          (m) => m.id == material['materialId'] as String,
                                        )
                                        .name;
                                    final materialUnit = _materials
                                        .firstWhere(
                                          (m) => m.id == material['materialId'] as String,
                                        )
                                        .unit;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: Colors.green.shade50,
                                      child: ListTile(
                                        leading: Icon(Icons.check_circle, color: Colors.green.shade700),
                                        title: Text(materialName),
                                        subtitle: Text(
                                          '${material['quantityPerUnit'].toStringAsFixed(4)} $materialUnit / kus',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Materiály (štandardný režim)
                  if (!_useMixerMode) ...[
                    Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.science, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Materiály (na 1 jednotku výroby)',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (_recipeMaterials.isNotEmpty)
                                Chip(
                                  label: Text('${_recipeMaterials.length} materiálov'),
                                  backgroundColor: Colors.green.shade50,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Zadajte množstvo každého materiálu potrebného na výrobu 1 jednotky (napr. 1 m²)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addMaterial,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Pridať materiál'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_recipeMaterials.isNotEmpty) ...[
                            ..._recipeMaterials.asMap().entries.map((entry) {
                              final index = entry.key;
                              final material = entry.value;
                              final materialName = _materials
                                  .firstWhere(
                                    (m) => m.id == material['materialId'] as String,
                                  )
                                  .name;
                              final materialUnit = _materials
                                  .firstWhere(
                                    (m) => m.id == material['materialId'] as String,
                                  )
                                  .unit;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Colors.grey.shade50,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Colors.green.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    materialName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${material['quantityPerUnit']} $materialUnit / jednotka',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editMaterial(index),
                                        tooltip: 'Upraviť',
                                        color: Colors.blue,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _removeMaterial(index),
                                        tooltip: 'Odstrániť',
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Žiadne materiály',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pridajte materiály pomocou tlačidla vyššie',
                                    style: TextStyle(
                                      color: Colors.grey[500],
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
                  ],
                  const SizedBox(height: 32),
                  // Footer s validáciou
                  if (_recipeMaterials.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        border: Border(
                          top: BorderSide(
                            color: Colors.purple.shade400,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pridajte aspoň jeden materiál do receptu',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _recipeMaterials.isEmpty ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.recipe == null ? Icons.add_circle : Icons.save),
                        const SizedBox(width: 8),
                        Text(
                          widget.recipe == null
                              ? 'Vytvoriť recept'
                              : 'Uložiť zmeny',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
    _piecesFromMixerController.dispose();
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

class _MixerMaterialDialog extends StatefulWidget {
  final List<material_model.Material> materials;
  final Function(String materialId, double quantityForMixer) onAdd;

  const _MixerMaterialDialog({
    required this.materials,
    required this.onAdd,
  });

  @override
  State<_MixerMaterialDialog> createState() => _MixerMaterialDialogState();
}

class _MixerMaterialDialogState extends State<_MixerMaterialDialog> {
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať materiál do miešačky'),
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
              labelText: 'Množstvo pre jednu miešačku',
              border: OutlineInputBorder(),
              hintText: 'napr. 500 pre 500 kg cementu',
              helperText: 'Celkové množstvo materiálu pre jednu miešačku',
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

