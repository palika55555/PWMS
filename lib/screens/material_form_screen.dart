import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/material.dart';
import '../services/api_service.dart';

class MaterialFormScreen extends StatefulWidget {
  final Material? material;

  const MaterialFormScreen({super.key, this.material});

  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      _nameController.text = widget.material!.name;
      _unitController.text = widget.material!.unit;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (widget.material == null) {
        // Create new
        await apiService.createMaterial(
          _nameController.text.trim(),
          _unitController.text.trim(),
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materiál bol vytvorený')),
          );
        }
      } else {
        // Update existing
        await apiService.updateMaterial(
          widget.material!.id,
          _nameController.text.trim(),
          _unitController.text.trim(),
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materiál bol aktualizovaný')),
          );
        }
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
        title: Text(widget.material == null ? 'Nový materiál' : 'Upraviť materiál'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Názov materiálu',
                border: OutlineInputBorder(),
                hintText: 'napr. Cement, Štrk, Voda',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Zadajte názov materiálu';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Jednotka',
                border: OutlineInputBorder(),
                hintText: 'napr. kg, l, m³',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Zadajte jednotku';
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
              child: Text(widget.material == null ? 'Vytvoriť' : 'Uložiť zmeny'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }
}

