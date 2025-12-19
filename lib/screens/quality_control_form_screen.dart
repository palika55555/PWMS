import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class QualityControlFormScreen extends StatefulWidget {
  final String batchId;

  const QualityControlFormScreen({
    super.key,
    required this.batchId,
  });

  @override
  State<QualityControlFormScreen> createState() => _QualityControlFormScreenState();
}

class _QualityControlFormScreenState extends State<QualityControlFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _testNameController = TextEditingController();
  final _testTypeController = TextEditingController();
  final _resultValueController = TextEditingController();
  final _resultTextController = TextEditingController();
  final _notesController = TextEditingController();
  final _testedByController = TextEditingController();

  String _selectedTestType = 'strength';
  bool _passed = false;
  bool _isLoading = false;

  final List<String> _testTypes = [
    'strength',
    'resistance',
    'dimensions',
    'weight',
    'appearance',
    'other',
  ];

  @override
  void dispose() {
    _testNameController.dispose();
    _testTypeController.dispose();
    _resultValueController.dispose();
    _resultTextController.dispose();
    _notesController.dispose();
    _testedByController.dispose();
    super.dispose();
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createQualityTest(
        batchId: widget.batchId,
        testType: _selectedTestType,
        testName: _testNameController.text,
        resultValue: _resultValueController.text.isNotEmpty
            ? double.tryParse(_resultValueController.text)
            : null,
        resultText: _resultTextController.text.isNotEmpty
            ? _resultTextController.text
            : null,
        passed: _passed,
        testedBy: _testedByController.text.isNotEmpty
            ? _testedByController.text
            : null,
        notes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test kvality bol uložený')),
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
        title: const Text('Nový test kvality'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTestType,
              decoration: const InputDecoration(
                labelText: 'Typ testu',
                border: OutlineInputBorder(),
              ),
              items: _testTypes.map((type) {
                String label;
                switch (type) {
                  case 'strength':
                    label = 'Pevnosť';
                    break;
                  case 'resistance':
                    label = 'Odolnosť';
                    break;
                  case 'dimensions':
                    label = 'Rozmery';
                    break;
                  case 'weight':
                    label = 'Hmotnosť';
                    break;
                  case 'appearance':
                    label = 'Vzhľad';
                    break;
                  default:
                    label = 'Iné';
                }
                return DropdownMenuItem(
                  value: type,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTestType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _testNameController,
              decoration: const InputDecoration(
                labelText: 'Názov testu *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Zadajte názov testu';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _resultValueController,
              decoration: const InputDecoration(
                labelText: 'Hodnota výsledku',
                border: OutlineInputBorder(),
                helperText: 'Číselná hodnota (voliteľné)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _resultTextController,
              decoration: const InputDecoration(
                labelText: 'Textový výsledok',
                border: OutlineInputBorder(),
                helperText: 'Textový popis výsledku (voliteľné)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Test prešiel'),
              subtitle: const Text('Označte, ak test prešiel úspešne'),
              value: _passed,
              onChanged: (value) {
                setState(() => _passed = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _testedByController,
              decoration: const InputDecoration(
                labelText: 'Testoval',
                border: OutlineInputBorder(),
                helperText: 'Meno osoby, ktorá test vykonala',
              ),
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
              onPressed: _isLoading ? null : _saveTest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Uložiť test'),
            ),
          ],
        ),
      ),
    );
  }
}

