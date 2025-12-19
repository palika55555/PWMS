import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/production_type.dart';
import '../services/api_service.dart';

class ProductionPlanFormScreen extends StatefulWidget {
  const ProductionPlanFormScreen({super.key});

  @override
  State<ProductionPlanFormScreen> createState() => _ProductionPlanFormScreenState();
}

class _ProductionPlanFormScreenState extends State<ProductionPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  List<ProductionType> _productionTypes = [];
  List<dynamic> _recipes = [];
  ProductionType? _selectedType;
  dynamic _selectedRecipe;
  DateTime _selectedDate = DateTime.now();
  String _priority = 'normal';
  bool _isLoading = false;
  bool _loadingTypes = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final types = await apiService.getProductionTypes();
      setState(() {
        _productionTypes = types;
        _loadingTypes = false;
      });
    } catch (e) {
      setState(() => _loadingTypes = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní typov: $e')),
        );
      }
    }
  }

  Future<void> _loadRecipes(String productionTypeId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final recipes = await apiService.getRecipesByProductionType(productionTypeId);
      setState(() {
        _recipes = recipes;
        _selectedRecipe = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní receptov: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte typ výroby')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createProductionPlan(
        productionTypeId: _selectedType!.id,
        plannedQuantity: double.parse(_quantityController.text),
        plannedDate: _selectedDate,
        priority: _priority,
        assignedRecipeId: _selectedRecipe?['id'],
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Výrobný plán bol vytvorený')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri ukladaní: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nový výrobný plán'),
      ),
      body: _loadingTypes
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  DropdownButtonFormField<ProductionType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Typ výroby *',
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
                      });
                      if (value != null) {
                        _loadRecipes(value.id);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedType != null && _recipes.isNotEmpty)
                    DropdownButtonFormField<dynamic>(
                      value: _selectedRecipe,
                      decoration: const InputDecoration(
                        labelText: 'Receptúra (voliteľné)',
                        border: OutlineInputBorder(),
                      ),
                      items: _recipes.map((recipe) {
                        return DropdownMenuItem(
                          value: recipe,
                          child: Text(recipe['name'] ?? 'Neznámy recept'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedRecipe = value);
                      },
                    ),
                  if (_selectedType != null && _recipes.isNotEmpty)
                    const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Plánované množstvo *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Zadajte množstvo';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Zadajte platné číslo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Plánovaný dátum *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priorita',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'urgent',
                        child: Text('Urgentné'),
                      ),
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Normálne'),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Text('Nízka'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _priority = value);
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : _savePlan,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Vytvoriť plán'),
                  ),
                ],
              ),
            ),
    );
  }
}

