import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class IssueScreen extends StatefulWidget {
  const IssueScreen({super.key});

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  final _formKey = GlobalKey<FormState>();
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _recipientController = TextEditingController();
  final _reasonController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _issueDate = DateTime.now();
  String _selectedReason = 'vyroba';
  List<material_model.Material> _materials = [];
  bool _loading = true;

  final List<Map<String, String>> _reasons = [
    {'value': 'vyroba', 'label': 'Výroba'},
    {'value': 'predaj', 'label': 'Predaj'},
    {'value': 'vrat', 'label': 'Vrátenie'},
    {'value': 'skartacia', 'label': 'Skartácia'},
    {'value': 'iné', 'label': 'Iné'},
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
      _materials = materials;
      _loading = false;
    });
  }

  Future<void> _saveIssue() async {
    if (!_formKey.currentState!.validate() || _selectedMaterial == null) {
      return;
    }

    final quantity = double.parse(_quantityController.text);
    
    // Check if enough stock available
    if (quantity > _selectedMaterial!.currentStock) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nedostatok zásob'),
            content: Text(
              'Dostupné množstvo: ${_selectedMaterial!.currentStock} ${_selectedMaterial!.unit}\n'
              'Požadované množstvo: $quantity ${_selectedMaterial!.unit}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrušiť'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmIssue(quantity);
                },
                child: const Text('Pokračovať', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        );
      }
      return;
    }

    _confirmIssue(quantity);
  }

  Future<void> _confirmIssue(double quantity) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final reasonLabel = _reasons.firstWhere((r) => r['value'] == _selectedReason)['label']!;
    final reasonText = _reasonController.text.isNotEmpty
        ? '$reasonLabel - ${_reasonController.text}'
        : reasonLabel;
    
    final movement = StockMovement(
      movementType: 'issue',
      materialId: _selectedMaterial!.id,
      quantity: quantity,
      unit: _selectedMaterial!.unit,
      documentNumber: _documentNumberController.text.isEmpty
          ? null
          : _documentNumberController.text,
      recipientName: _recipientController.text.isEmpty
          ? null
          : _recipientController.text,
      reason: reasonText,
      location: _locationController.text.isEmpty
          ? null
          : _locationController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      movementDate: DateFormat('yyyy-MM-dd').format(_issueDate),
      createdBy: 'Current User', // TODO: Get from auth
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await dbProvider.insertStockMovement(movement);
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Výdaj tovaru bol úspešne zaznamenaný'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
          ),
        );
        
        // Clear form
        _quantityController.clear();
        _documentNumberController.clear();
        _recipientController.clear();
        _reasonController.clear();
        _locationController.clear();
        _notesController.clear();
        setState(() {
          _selectedMaterial = null;
          _selectedReason = 'vyroba';
        });
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
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
    _quantityController.dispose();
    _documentNumberController.dispose();
    _recipientController.dispose();
    _reasonController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Výdaj tovaru'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Material selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Materiál',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<material_model.Material>(
                      value: _selectedMaterial,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte materiál *',
                        border: OutlineInputBorder(),
                      ),
                      items: _materials.map((material) {
                        return DropdownMenuItem(
                          value: material,
                          child: Text('${material.name} (${material.type})'),
                        );
                      }).toList(),
                      onChanged: (material) {
                        setState(() {
                          _selectedMaterial = material;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vyberte materiál';
                        }
                        return null;
                      },
                    ),
                    if (_selectedMaterial != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedMaterial!.currentStock <= _selectedMaterial!.minStock
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Dostupné:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: _selectedMaterial!.currentStock <= _selectedMaterial!.minStock
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                            Text(
                              '${_selectedMaterial!.currentStock} ${_selectedMaterial!.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _selectedMaterial!.currentStock <= _selectedMaterial!.minStock
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Issue date
            Card(
              child: ListTile(
                title: const Text('Dátum výdaja'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_issueDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _issueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _issueDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Quantity
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _quantityController,
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
              ),
            ),
            const SizedBox(height: 16),
            
            // Reason
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Dôvod výdaja *',
                        border: OutlineInputBorder(),
                      ),
                      items: _reasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason['value'],
                          child: Text(reason['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Dodatočný popis',
                        border: OutlineInputBorder(),
                        helperText: 'Voliteľné',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Document number
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _documentNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Číslo dokladu',
                    border: OutlineInputBorder(),
                    helperText: 'Např. číslo výdajky',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Recipient
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(
                    labelText: 'Príjemca',
                    border: OutlineInputBorder(),
                    helperText: 'Názov príjemcu',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Location
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Miesto skladu',
                    border: OutlineInputBorder(),
                    helperText: 'Voliteľné',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámky',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _saveIssue,
              icon: const Icon(Icons.send),
              label: const Text('Zaznamenať výdaj'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



