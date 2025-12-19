import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/production_type.dart';
import '../models/material.dart' as material_model;
import '../models/warehouse.dart';
import 'recipe_form_screen.dart';

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
  List<Map<String, dynamic>> _recipeMaterials = [];
  bool _isLoading = true;
  bool _useRecipe = false;
  String? _selectedRecipeId; // ID vybranej receptúry pre kontrolu

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
          SnackBar(
            content: Text('Chyba pri načítaní dát: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('Chyba pri načítaní receptov: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadRecipeMaterials(String recipeId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final recipe = await apiService.getRecipeById(recipeId);
      
      if (mounted && recipe['materials'] != null) {
        setState(() {
          _recipeMaterials = List<Map<String, dynamic>>.from(recipe['materials']);
        });
      }
    } catch (e) {
      debugPrint('Chyba pri načítaní materiálov z receptúry: $e');
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Materiály vypočítané pre ${_quantity.toStringAsFixed(2)} jednotiek',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri výpočte materiálov: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addMaterial() {
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprv musíte vytvoriť materiály'),
          backgroundColor: Colors.orange,
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Upraviť ${materialObj.name}'),
          ],
        ),
        content: TextFormField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Množstvo',
            suffixText: materialObj.unit,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.scale),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Uložiť'),
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
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vyberte typ výroby'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pridajte materiály alebo použite recept'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Kontrola vyrobku a receptúry
    if (_useRecipe && _selectedRecipe != null) {
      // Skontrolujeme, či receptúra patrí k vybranému typu výroby
      final recipeProductionTypeId = _selectedRecipe['production_type_id'] as String?;
      if (recipeProductionTypeId != null && recipeProductionTypeId != _selectedType!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vybraná receptúra nepatrí k vybranému typu výroby'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Skontrolujeme, či sú materiály z receptúry správne
      if (_recipeMaterials.isEmpty && _selectedMaterials.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receptúra neobsahuje žiadne materiály'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Kontrola dostupnosti materiálov
    final missingMaterials = <String>[];
    final missingMaterialsDetails = <Map<String, dynamic>>[];
    for (final material in _selectedMaterials) {
      final materialId = material['materialId'] as String;
      final requiredQuantity = (material['quantity'] as num).toDouble();
      final availableQuantity = _getAvailableQuantity(materialId);
      if (!_hasEnoughMaterial(materialId, requiredQuantity)) {
        final materialName = _materials
            .firstWhere((m) => m.id == materialId)
            .name;
        missingMaterials.add(materialName);
        missingMaterialsDetails.add({
          'name': materialName,
          'required': requiredQuantity,
          'available': availableQuantity,
          'missing': requiredQuantity - availableQuantity,
        });
      }
    }

    // Ak sú nedostatočné materiály, uložíme so stavom "pending"
    final productionStatus = missingMaterials.isNotEmpty ? 'pending' : 'completed';
    final recipeId = _selectedRecipeId;

    if (missingMaterials.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Nedostatok materiálov'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nasledujúce materiály nie sú dostupné v dostatočnom množstve:'),
                const SizedBox(height: 12),
                ...missingMaterialsDetails.map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      detail['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Potrebné: ${detail['required'].toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                'Dostupné: ${detail['available'].toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                'Chýba: ${detail['missing'].toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Výroba bude uložená so stavom "Na proces" a nebude odpočítaná zo skladu, kým nebudú materiály doplnené.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Uložiť na proces'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
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
      final result = await apiService.createProduction(
        productionTypeId: _selectedType!.id,
        quantity: _quantity,
        materials: _selectedMaterials,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        productionDate: _productionDate,
        status: productionStatus,
        recipeId: recipeId,
      );
      if (mounted) {
        Navigator.pop(context);
        final statusMessage = result.status == 'pending'
            ? 'Výroba bola uložená so stavom "Na proces". Šarža a QR kód boli vytvorené.'
            : 'Výroba bola úspešne vytvorená. Šarža a QR kód boli vytvorené.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.status == 'pending' ? Icons.pending_actions : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(statusMessage),
                ),
              ],
            ),
            backgroundColor: result.status == 'pending' ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri vytváraní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Základné informácie',
      icon: Icons.info_outline,
      iconColor: Colors.blue,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ProductionType>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Typ výroby',
                  hintText: 'Vyberte typ výroby',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                        _selectedRecipeId = null;
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
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Vytvoriť nový typ výroby',
              child: ElevatedButton.icon(
                onPressed: () => _showCreateProductionTypeDialog(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Nový'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            labelText: 'Množstvo',
            hintText: 'Zadajte množstvo',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.numbers),
            suffixText: 'ks',
            filled: true,
            fillColor: Colors.grey.shade50,
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
        const SizedBox(height: 20),
        InkWell(
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
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dátum výroby',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_productionDate.day}.${_productionDate.month}.${_productionDate.year} ${_productionDate.hour.toString().padLeft(2, '0')}:${_productionDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeSection() {
    return _buildSectionCard(
      title: 'Receptúra',
      icon: Icons.menu_book,
      iconColor: Colors.purple,
      children: [
        SwitchListTile(
          title: const Text(
            'Použiť receptúru',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _useRecipe
                ? 'Materiály sa vypočítajú automaticky'
                : 'Pridajte materiály manuálne',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          value: _useRecipe,
          onChanged: (value) {
            setState(() {
              _useRecipe = value;
              if (!_useRecipe) {
                _selectedRecipe = null;
                _selectedRecipeId = null;
                _selectedMaterials = [];
              }
            });
            if (_useRecipe && _selectedType != null) {
              _loadRecipes();
            }
          },
          secondary: Icon(
            _useRecipe ? Icons.check_circle : Icons.cancel,
            color: _useRecipe ? Colors.green : Colors.grey,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        if (_useRecipe && _selectedType != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<dynamic>(
                  value: _selectedRecipe,
                  decoration: InputDecoration(
                    labelText: 'Vyberte recept',
                    hintText: 'Vyberte receptúru',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.menu_book),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _recipes.map((recipe) {
                    return DropdownMenuItem(
                      value: recipe,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            recipe['name'] ?? 'Neznámy recept',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (_selectedType != null)
                            Text(
                              'Pre: ${_selectedType!.name}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedRecipe = value;
                      _selectedRecipeId = value != null ? value['id'] : null;
                      _recipeMaterials = [];
                      _selectedMaterials = [];
                    });
                    if (value != null) {
                      await _loadRecipeMaterials(value['id']);
                      if (_quantity > 0) {
                        _calculateMaterialsFromRecipe();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Vytvoriť novú receptúru',
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToCreateRecipe(),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Nový'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.purple.shade50,
                    foregroundColor: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedRecipe != null && _recipeMaterials.isNotEmpty && _quantity == 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Materiály v receptúre (na 1 jednotku):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._recipeMaterials.map((recipeMat) {
                    final materialId = recipeMat['material_id'] as String? ?? 
                                       recipeMat['materialId'] as String? ?? '';
                    final quantityPerUnit = (recipeMat['quantity_per_unit'] as num?)?.toDouble() ?? 
                                           (recipeMat['quantityPerUnit'] as num?)?.toDouble() ?? 0.0;
                    final material = _materials.firstWhere(
                      (m) => m.id == materialId,
                      orElse: () => material_model.Material(
                        id: materialId,
                        name: recipeMat['material_name'] as String? ?? 'Neznámy',
                        unit: recipeMat['unit'] as String? ?? '',
                      ),
                    );
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              material.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${quantityPerUnit.toStringAsFixed(2)} ${material.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Po zadaní množstva sa automaticky vypočítajú potrebné množstvá materiálov.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildMaterialsSection() {
    return _buildSectionCard(
      title: 'Materiály',
      icon: Icons.inventory_2,
      iconColor: Colors.orange,
      children: [
        if (!_useRecipe) ...[
          ElevatedButton.icon(
            onPressed: _addMaterial,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Pridať materiál'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_selectedMaterials.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  _useRecipe
                      ? 'Zadajte množstvo a vyberte receptúru'
                      : 'Pridajte materiály manuálne',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (_useRecipe && _selectedMaterials.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Materiály boli automaticky vypočítané z receptúry. Môžete ich upraviť kliknutím na ikonu edit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ..._selectedMaterials.asMap().entries.map((entry) {
            final index = entry.key;
            final material = entry.value;
            final materialId = material['materialId'] as String;
            final requiredQuantity = (material['quantity'] as num).toDouble();
            final materialName = _materials
                .firstWhere((m) => m.id == materialId)
                .name;
            final materialUnit = _materials
                .firstWhere((m) => m.id == materialId)
                .unit;
            final availableQuantity = _getAvailableQuantity(materialId);
            final hasEnough = _hasEnoughMaterial(materialId, requiredQuantity);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: hasEnough ? 1 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hasEnough ? Colors.grey.shade300 : Colors.red.shade300,
                  width: hasEnough ? 1 : 2,
                ),
              ),
              color: hasEnough ? null : Colors.red.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasEnough
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasEnough ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: hasEnough ? Colors.green.shade700 : Colors.red.shade700,
                    size: 28,
                  ),
                ),
                title: Text(
                  materialName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.scale,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Potrebné: ${requiredQuantity.toStringAsFixed(2)} $materialUnit',
                            style: TextStyle(
                              color: _useRecipe ? Colors.green.shade700 : Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_useRecipe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'z receptúry',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.warehouse,
                            size: 14,
                            color: hasEnough ? Colors.grey.shade600 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dostupné: ${availableQuantity.toStringAsFixed(2)} $materialUnit',
                            style: TextStyle(
                              color: hasEnough
                                  ? Colors.grey.shade600
                                  : Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: hasEnough
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (!hasEnough) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Nedostatok: ${(requiredQuantity - availableQuantity).toStringAsFixed(2)} $materialUnit',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    _useRecipe ? Icons.edit : Icons.delete_outline,
                    color: _useRecipe ? Colors.blue : Colors.red,
                  ),
                  onPressed: _useRecipe
                      ? () => _editMaterialFromRecipe(index)
                      : () => _removeMaterial(index),
                  tooltip: _useRecipe ? 'Upraviť množstvo' : 'Odstrániť',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionCard(
      title: 'Poznámky',
      icon: Icons.note_outlined,
      iconColor: Colors.teal,
      children: [
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Poznámky (voliteľné)',
            hintText: 'Zadajte poznámky k výrobe...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.note),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Nová výroba',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBasicInfoSection(),
                    _buildRecipeSection(),
                    _buildMaterialsSection(),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'Vytvoriť výrobu',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showCreateProductionTypeDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Vytvoriť nový typ výroby'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Názov typu výroby *',
                  hintText: 'napr. Dlažba, Tvárnice',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Popis (voliteľné)',
                  hintText: 'Zadajte popis typu výroby...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Vytvoriť'),
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim().isEmpty
                  ? null
                  : descriptionController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zadajte názov typu výroby'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Skontrolujeme, či už existuje
              final existing = _productionTypes.firstWhere(
                (t) => t.name.toLowerCase() == name.toLowerCase(),
                orElse: () => ProductionType(
                  id: '',
                  name: '',
                ),
              );

              if (existing.id.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Typ výroby "$name" už existuje'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                final apiService = Provider.of<ApiService>(context, listen: false);
                final newType = await apiService.createProductionType(name, description);

                if (context.mounted) {
                  Navigator.pop(context);
                  
                  // Najprv obnovíme dáta
                  await _loadData();
                  
                  // Potom nájdeme nový typ v zozname a nastavíme ho
                  // Musíme použiť inštanciu z _productionTypes, nie newType, aby sa zhodovala s items v dropdown
                  final updatedType = _productionTypes.firstWhere(
                    (t) => t.id == newType.id,
                    orElse: () => newType,
                  );
                  
                  setState(() {
                    _selectedType = updatedType;
                  });
                  
                  // Načítame recepty pre nový typ
                  if (_selectedType != null) {
                    _loadRecipes();
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Typ výroby "$name" bol vytvorený'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chyba pri vytváraní typu výroby: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCreateRecipe() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprv vyberte typ výroby'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeFormScreen(
          productionTypeId: _selectedType!.id,
        ),
      ),
    );

    // Obnovíme recepty po návrate
    if (result == true && mounted) {
      await _loadRecipes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receptúra bola vytvorená. Môžete ju teraz vybrať.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Pridať materiál'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.materials.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'Žiadne materiály',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Najprv musíte vytvoriť materiály v sekcii Sklad alebo spustiť seed script.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<material_model.Material>(
                value: _selectedMaterial,
                decoration: InputDecoration(
                  labelText: 'Materiál',
                  hintText: 'Vyberte materiál',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                validator: (value) {
                  if (value == null) {
                    return 'Vyberte materiál';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Množstvo',
                  hintText: 'Zadajte množstvo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadajte množstvo';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Množstvo musí byť kladné číslo';
                  }
                  return null;
                },
                autofocus: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        if (widget.materials.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Pridať'),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                if (_selectedMaterial != null &&
                    _quantityController.text.isNotEmpty) {
                  final quantity = double.tryParse(_quantityController.text);
                  if (quantity != null && quantity > 0) {
                    widget.onAdd(_selectedMaterial!.id, quantity);
                    Navigator.pop(context);
                  }
                }
              }
            },
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
