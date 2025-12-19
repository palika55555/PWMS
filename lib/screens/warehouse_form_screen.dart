import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/material.dart' as material_model;

class WarehouseFormScreen extends StatefulWidget {
  const WarehouseFormScreen({super.key});

  @override
  State<WarehouseFormScreen> createState() => _WarehouseFormScreenState();
}

class _WarehouseFormScreenState extends State<WarehouseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();
  List<material_model.Material> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final materials = await apiService.getMaterials();
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní materiálov: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte materiál')),
      );
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final quantity = double.parse(_quantityController.text);
      await apiService.createWarehouseEntry(_selectedMaterial!.id, quantity);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Materiál bol pridaný na sklad')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri pridávaní: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pridať na sklad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  DropdownButtonFormField<material_model.Material>(
                    value: _selectedMaterial,
                    decoration: const InputDecoration(
                      labelText: 'Materiál',
                      border: OutlineInputBorder(),
                    ),
                    items: _materials.map((material) {
                      return DropdownMenuItem<material_model.Material>(
                        value: material,
                        child: Text('${material.name} (${material.unit})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedMaterial = value);
                    },
                    validator: (value) {
                      if (value == null) return 'Vyberte materiál';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Množstvo',
                      hintText: _selectedMaterial?.unit != null
                          ? 'v ${_selectedMaterial!.unit}'
                          : null,
                      border: const OutlineInputBorder(),
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Pridať na sklad'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
