import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import 'bulk_receipt_screen.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  material_model.Material? _selectedMaterial;
  final _quantityController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _supplierController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _productNoteController = TextEditingController();
  final _purchasePriceWithoutVatController = TextEditingController();
  final _purchasePriceWithVatController = TextEditingController();
  final _vatRateController = TextEditingController(text: '20');
  DateTime _receiptDate = DateTime.now();
  DateTime? _deliveryDate;
  DateTime? _expirationDate;
  String _selectedCategory = 'warehouse'; // warehouse, production, retail, overhead
  List<material_model.Material> _materials = [];
  List<Supplier> _suppliers = [];
  List<Warehouse> _warehouses = [];
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final suppliers = await dbProvider.getSuppliers();
    final warehouses = await dbProvider.getWarehouses(activeOnly: true);
    setState(() {
      _materials = materials;
      _suppliers = suppliers;
      _warehouses = warehouses;
      _loading = false;
    });
  }

  // Helper function to parse number with comma support
  double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _calculatePriceWithVat() {
    final priceWithoutVat = _parseNumber(_purchasePriceWithoutVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    if (priceWithoutVat != null && priceWithoutVat > 0) {
      if (vatRate == 0) {
        // If VAT is 0%, price with VAT equals price without VAT
        _purchasePriceWithVatController.text = priceWithoutVat.toStringAsFixed(2);
      } else {
        final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
        _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
      }
    }
  }

  void _calculatePriceWithoutVat() {
    final priceWithVat = _parseNumber(_purchasePriceWithVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    if (priceWithVat != null && priceWithVat > 0) {
      if (vatRate == 0) {
        // If VAT is 0%, price without VAT equals price with VAT
        _purchasePriceWithoutVatController.text = priceWithVat.toStringAsFixed(2);
      } else {
        final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
        _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
      }
    }
  }

  String? _buildNotesWithCategory() {
    String? notes = _notesController.text.isEmpty ? null : _notesController.text;
    final categoryNote = 'Kategória: ${_getCategoryName(_selectedCategory)}';
    
    if (notes != null && !notes.contains('Kategória:')) {
      return '$categoryNote. $notes';
    } else if (notes == null) {
      return categoryNote;
    }
    return notes;
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'warehouse':
        return 'Sklad';
      case 'production':
        return 'Výroba';
      case 'retail':
        return 'Maloobchod';
      case 'overhead':
        return 'Režijný materiál';
      default:
        return category;
    }
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() || _selectedMaterial == null) {
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final quantity = _parseNumber(_quantityController.text) ?? 0;
    final priceWithoutVat = _purchasePriceWithoutVatController.text.trim().isEmpty
        ? null
        : _parseNumber(_purchasePriceWithoutVatController.text);
    final priceWithVat = _purchasePriceWithVatController.text.trim().isEmpty
        ? null
        : _parseNumber(_purchasePriceWithVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 20.0;
    
    final movement = StockMovement(
      movementType: 'receipt',
      materialId: _selectedMaterial!.id,
      quantity: quantity,
      unit: _selectedMaterial!.unit,
      documentNumber: _documentNumberController.text.isEmpty
          ? null
          : _documentNumberController.text,
      supplierName: _selectedSupplier?.name ?? (_supplierController.text.isEmpty
          ? null
          : _supplierController.text),
      location: _locationController.text.isEmpty
          ? null
          : _locationController.text,
      notes: _buildNotesWithCategory(),
      productNote: _productNoteController.text.isEmpty
          ? null
          : _productNoteController.text,
      expirationDate: _expirationDate != null
          ? DateFormat('yyyy-MM-dd').format(_expirationDate!)
          : null,
      purchasePriceWithoutVat: priceWithoutVat,
      purchasePriceWithVat: priceWithVat,
      vatRate: (priceWithoutVat != null || priceWithVat != null) ? vatRate : null,
      supplierId: _selectedSupplier?.id,
      warehouseId: _selectedWarehouse?.id,
      movementDate: DateFormat('yyyy-MM-dd').format(_receiptDate),
      deliveryDate: _deliveryDate != null ? DateFormat('yyyy-MM-dd').format(_deliveryDate!) : null,
      createdBy: 'Current User', // TODO: Get from auth
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      // Update material category and VAT rate if changed
      bool materialNeedsUpdate = false;
      material_model.Material updatedMaterial = _selectedMaterial!;
      
      if (_selectedMaterial!.category != _selectedCategory) {
        materialNeedsUpdate = true;
        updatedMaterial = updatedMaterial.copyWith(
          category: _selectedCategory,
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
      
      // Update VAT rate in material if VAT rate is provided in receipt
      // Update even if no prices are provided, as VAT rate is important for the material
      if (_selectedMaterial!.vatRate != vatRate) {
        materialNeedsUpdate = true;
        updatedMaterial = updatedMaterial.copyWith(
          vatRate: vatRate,
          updatedAt: DateTime.now().toIso8601String(),
        );
      }
      
      if (materialNeedsUpdate) {
        await dbProvider.updateMaterial(updatedMaterial);
        // Update local reference
        setState(() {
          _selectedMaterial = updatedMaterial;
        });
      }
      
      await dbProvider.insertStockMovement(movement);
      
      // If prices are provided, create price history entry
      // Calculate missing price if only one is provided
      // Price history will be created when receipt is approved
      // This ensures only approved receipts are added to price history
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Príjem tovaru bol úspešne zaznamenaný'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
        
        // Clear form
        _quantityController.clear();
        _documentNumberController.clear();
        _supplierController.clear();
        _locationController.clear();
        _notesController.clear();
        _productNoteController.clear();
        setState(() {
          _expirationDate = null;
        });
        _purchasePriceWithoutVatController.clear();
        _purchasePriceWithVatController.clear();
        _vatRateController.text = '20';
        setState(() {
          _selectedMaterial = null;
          _selectedSupplier = null;
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
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
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
    _supplierController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _productNoteController.dispose();
    _purchasePriceWithoutVatController.dispose();
    _purchasePriceWithVatController.dispose();
    _vatRateController.dispose();
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
        title: const Text('Príjem tovaru'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkReceiptScreen(),
                ),
              );
              if (result == true) {
                _loadMaterials();
              }
            },
            tooltip: 'Hromadný príjem',
          ),
        ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Materiál',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showCreateMaterialDialog(),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Nový materiál'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<material_model.Material>(
                      value: _selectedMaterial,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte materiál *',
                        border: OutlineInputBorder(),
                        helperText: 'Alebo vytvorte nový materiál',
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
                          // Update category to match selected material
                          if (material != null) {
                            _selectedCategory = material.category;
                            // Load VAT rate from material if it exists
                            if (material.vatRate != null) {
                              _vatRateController.text = material.vatRate!.toStringAsFixed(0);
                            }
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vyberte materiál alebo vytvorte nový';
                        }
                        return null;
                      },
                    ),
                    if (_selectedMaterial != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aktuálny stav:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            Text(
                              '${_selectedMaterial!.currentStock} ${_selectedMaterial!.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade900,
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
            
            // Receipt date
            Card(
              child: ListTile(
                title: const Text('Dátum príjmu'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_receiptDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _receiptDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _receiptDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Delivery date
            Card(
              child: ListTile(
                title: const Text('Dátum dodania'),
                subtitle: Text(_deliveryDate != null
                    ? DateFormat('dd.MM.yyyy').format(_deliveryDate!)
                    : 'Nie je zadaný'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_deliveryDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _deliveryDate = null;
                          });
                        },
                        tooltip: 'Odstrániť dátum dodania',
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _deliveryDate ?? _receiptDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _deliveryDate = date;
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Zadajte množstvo';
                    }
                    final parsed = _parseNumber(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Zadajte platné množstvo';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.contains(',')) {
                      final newValue = value.replaceAll(',', '.');
                      _quantityController.value = TextEditingValue(
                        text: newValue,
                        selection: TextSelection.collapsed(offset: newValue.length),
                      );
                    }
                  },
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
                    labelText: 'Číslo dodacieho listu',
                    border: OutlineInputBorder(),
                    helperText: 'Číslo dodacieho listu od dodávateľa',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Supplier
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dodávateľ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Supplier>(
                      value: _selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte dodávateľa',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: [
                        const DropdownMenuItem<Supplier>(
                          value: null,
                          child: Text('Žiadny (zadať manuálne)'),
                        ),
                        ..._suppliers.map((supplier) {
                          return DropdownMenuItem<Supplier>(
                            value: supplier,
                            child: Text(supplier.name),
                          );
                        }),
                      ],
                      onChanged: (supplier) {
                        setState(() {
                          _selectedSupplier = supplier;
                          if (supplier != null) {
                            _supplierController.text = supplier.name;
                          } else {
                            _supplierController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Alebo zadajte manuálne',
                        border: OutlineInputBorder(),
                        helperText: 'Ak ste nevybrali dodávateľa zo zoznamu',
                      ),
                      enabled: _selectedSupplier == null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Warehouse selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sklad *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Warehouse>(
                      value: _selectedWarehouse,
                      decoration: const InputDecoration(
                        labelText: 'Vyberte sklad',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warehouse),
                      ),
                      items: _warehouses.map((warehouse) {
                        return DropdownMenuItem<Warehouse>(
                          value: warehouse,
                          child: Text(warehouse.name),
                        );
                      }).toList(),
                      onChanged: (warehouse) {
                        setState(() {
                          _selectedWarehouse = warehouse;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Prosím vyberte sklad';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Prices section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade50,
                      Colors.amber.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.euro, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Ceny pri príjme (voliteľné)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // VAT Rate
                    TextFormField(
                      controller: _vatRateController,
                      decoration: const InputDecoration(
                        labelText: 'Sadzba DPH (%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                        helperText: 'Môže byť 0% alebo iná sadzba',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculatePriceWithVat();
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Purchase price without VAT
                    TextFormField(
                      controller: _purchasePriceWithoutVatController,
                      decoration: InputDecoration(
                        labelText: 'Nákupná cena bez DPH (€)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.shopping_cart),
                        suffixText: _selectedMaterial != null 
                            ? 'za ${_selectedMaterial!.unit}'
                            : null,
                        helperText: 'Cena, za ktorú sme tovar nakúpili',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculatePriceWithVat();
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Purchase price with VAT
                    TextFormField(
                      controller: _purchasePriceWithVatController,
                      decoration: InputDecoration(
                        labelText: 'Nákupná cena s DPH (€)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.shopping_bag),
                        suffixText: _selectedMaterial != null 
                            ? 'za ${_selectedMaterial!.unit}'
                            : null,
                        helperText: 'Cena, za ktorú sme tovar nakúpili (s DPH)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        if (value.contains(',')) {
                          final newValue = value.replaceAll(',', '.');
                          _purchasePriceWithVatController.value = TextEditingValue(
                            text: newValue,
                            selection: TextSelection.collapsed(offset: newValue.length),
                          );
                        }
                        _calculatePriceWithoutVat();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ceny sa použijú na výpočet váženého priemeru nákupnej ceny',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
            
            // Product Note
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _productNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámka k produktu',
                    border: OutlineInputBorder(),
                    helperText: 'Voliteľné - špecifická poznámka k tomuto produktu',
                    icon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Expiration Date
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      helpText: 'Vyberte dátum expirácie',
                      cancelText: 'Zrušiť',
                      confirmText: 'Potvrdiť',
                    );
                    if (picked != null) {
                      setState(() {
                        _expirationDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Dátum expirácie produktu',
                      border: const OutlineInputBorder(),
                      helperText: 'Voliteľné - dátum expirácie tovaru',
                      icon: const Icon(Icons.calendar_today),
                      suffixIcon: _expirationDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _expirationDate = null;
                                });
                              },
                            )
                          : null,
                    ),
                    child: Text(
                      _expirationDate != null
                          ? DateFormat('dd.MM.yyyy').format(_expirationDate!)
                          : 'Kliknite pre výber dátumu',
                      style: TextStyle(
                        color: _expirationDate != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).hintColor,
                      ),
                    ),
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
                    helperText: 'Všeobecné poznámky k príjemke',
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _saveReceipt,
              icon: const Icon(Icons.check),
              label: const Text('Zaznamenať príjem'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateMaterialDialog() async {
    final nameController = TextEditingController();
    final pluController = TextEditingController();
    final eanController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final minStockController = TextEditingController(text: '0');
    final purchasePriceWithoutVatController = TextEditingController(text: _purchasePriceWithoutVatController.text);
    final purchasePriceWithVatController = TextEditingController(text: _purchasePriceWithVatController.text);
    final salePriceController = TextEditingController();
    final vatRateController = TextEditingController(text: _vatRateController.text);
    final recyclingFeeController = TextEditingController();
    
    String selectedType = 'other';
    String selectedCategory = 'warehouse';
    int? selectedSupplierId = _selectedSupplier?.id;
    bool hasRecyclingFee = false;
    
    final materialTypes = [
      {'value': 'cement', 'label': 'Cement'},
      {'value': 'aggregate', 'label': 'Štrk'},
      {'value': 'water', 'label': 'Voda'},
      {'value': 'plasticizer', 'label': 'Plastifikátor'},
      {'value': 'other', 'label': 'Iné'},
    ];
    
    final categories = [
      {'value': 'warehouse', 'label': 'Sklad'},
      {'value': 'production', 'label': 'Výroba'},
      {'value': 'retail', 'label': 'Maloobchod'},
      {'value': 'overhead', 'label': 'Režijný materiál'},
    ];
    
    // Pre-fill category from receipt screen if material is selected
    if (_selectedMaterial != null) {
      selectedCategory = _selectedMaterial!.category;
    }
    
    final units = ['kg', 't', 'm³', 'l', 'ks', 'm', 'm²'];
    
    final formKey = GlobalKey<FormState>();
    bool creating = false;
    
    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Vytvoriť nový materiál'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Názov materiálu *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Zadajte názov' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Type and Category
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Typ',
                            border: OutlineInputBorder(),
                          ),
                          items: materialTypes.map((type) {
                            return DropdownMenuItem(
                              value: type['value'],
                              child: Text(type['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedType = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategória',
                            border: OutlineInputBorder(),
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat['value'],
                              child: Text(cat['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Unit and Min Stock
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unitController.text,
                          decoration: const InputDecoration(
                            labelText: 'Jednotka *',
                            border: OutlineInputBorder(),
                          ),
                          items: units.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              unitController.text = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: minStockController,
                          decoration: const InputDecoration(
                            labelText: 'Min. stav',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // PLU and EAN
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: pluController,
                          decoration: const InputDecoration(
                            labelText: 'PLU kód',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: eanController,
                          decoration: const InputDecoration(
                            labelText: 'EAN kód',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Supplier
                  DropdownButtonFormField<int?>(
                    value: selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Predvolený dodávateľ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Žiadny'),
                      ),
                      ..._suppliers.map((supplier) {
                        return DropdownMenuItem<int?>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSupplierId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Prices section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ceny (voliteľné)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vatRateController,
                          decoration: const InputDecoration(
                            labelText: 'Sadzba DPH (%)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.percent),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            if (value.contains(',')) {
                              final newValue = value.replaceAll(',', '.');
                              vatRateController.value = TextEditingValue(
                                text: newValue,
                                selection: TextSelection.collapsed(offset: newValue.length),
                              );
                            }
                            final priceWithoutVat = _parseNumber(purchasePriceWithoutVatController.text);
                            final vatRate = _parseNumber(vatRateController.text) ?? 0.0;
                            if (priceWithoutVat != null && priceWithoutVat > 0) {
                              if (vatRate == 0) {
                                purchasePriceWithVatController.text = priceWithoutVat.toStringAsFixed(2);
                              } else {
                                final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
                                purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (context, setPriceState) => TextFormField(
                            controller: purchasePriceWithoutVatController,
                            decoration: InputDecoration(
                              labelText: 'Nákupná cena bez DPH (€)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.shopping_cart),
                              suffixText: 'za ${unitController.text}',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              if (value.contains(',')) {
                                final newValue = value.replaceAll(',', '.');
                                purchasePriceWithoutVatController.value = TextEditingValue(
                                  text: newValue,
                                  selection: TextSelection.collapsed(offset: newValue.length),
                                );
                              }
                              final priceWithoutVat = _parseNumber(purchasePriceWithoutVatController.text);
                              final vatRate = _parseNumber(vatRateController.text) ?? 0.0;
                              if (priceWithoutVat != null && priceWithoutVat > 0) {
                                if (vatRate == 0) {
                                  purchasePriceWithVatController.text = priceWithoutVat.toStringAsFixed(2);
                                } else {
                                  final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
                                  purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (context, setPriceState) => TextFormField(
                            controller: purchasePriceWithVatController,
                            decoration: InputDecoration(
                              labelText: 'Nákupná cena s DPH (€)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.shopping_bag),
                              suffixText: 'za ${unitController.text}',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              if (value.contains(',')) {
                                final newValue = value.replaceAll(',', '.');
                                purchasePriceWithVatController.value = TextEditingValue(
                                  text: newValue,
                                  selection: TextSelection.collapsed(offset: newValue.length),
                                );
                              }
                              final priceWithVat = _parseNumber(purchasePriceWithVatController.text);
                              final vatRate = _parseNumber(vatRateController.text) ?? 0.0;
                              if (priceWithVat != null && priceWithVat > 0) {
                                if (vatRate == 0) {
                                  purchasePriceWithoutVatController.text = priceWithVat.toStringAsFixed(2);
                                } else {
                                  final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
                                  purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: salePriceController,
                          decoration: InputDecoration(
                            labelText: 'Predajná cena (€)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.euro),
                            suffixText: 'za ${unitController.text}',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Recycling fee section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recyklačný poplatok',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: hasRecyclingFee,
                          onChanged: (value) {
                            setDialogState(() {
                              hasRecyclingFee = value ?? false;
                              if (!hasRecyclingFee) {
                                recyclingFeeController.clear();
                              }
                            });
                          },
                          title: const Text('Má recyklačný poplatok'),
                          subtitle: const Text('Označte, ak produkt má recyklačný poplatok'),
                          activeColor: Colors.teal.shade700,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        if (hasRecyclingFee) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: recyclingFeeController,
                            decoration: InputDecoration(
                              labelText: 'Suma recyklačného poplatku (€)',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.teal.shade300),
                              ),
                              prefixIcon: const Icon(Icons.euro),
                              helperText: 'Zadajte sumu recyklačného poplatku',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (hasRecyclingFee && (value == null || value.isEmpty)) {
                                return 'Zadajte sumu recyklačného poplatku';
                              }
                              if (hasRecyclingFee && value != null && value.isNotEmpty) {
                                final parsed = _parseNumber(value);
                                if (parsed == null || parsed < 0) {
                                  return 'Zadajte platnú sumu';
                                }
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.contains(',')) {
                                final newValue = value.replaceAll(',', '.');
                                recyclingFeeController.value = TextEditingValue(
                                  text: newValue,
                                  selection: TextSelection.collapsed(offset: newValue.length),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: creating ? null : () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                
                setDialogState(() => creating = true);
                
                try {
                  final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
                  
                  final material = material_model.Material(
                    name: nameController.text.trim(),
                    type: selectedType,
                    category: selectedCategory,
                    unit: unitController.text,
                    currentStock: 0,
                    minStock: _parseNumber(minStockController.text) ?? 0,
                    pluCode: pluController.text.trim().isEmpty ? null : pluController.text.trim(),
                    eanCode: eanController.text.trim().isEmpty ? null : eanController.text.trim(),
                    averagePurchasePriceWithoutVat: purchasePriceWithoutVatController.text.trim().isEmpty
                        ? null
                        : _parseNumber(purchasePriceWithoutVatController.text),
                    averagePurchasePriceWithVat: purchasePriceWithVatController.text.trim().isEmpty
                        ? null
                        : _parseNumber(purchasePriceWithVatController.text),
                    salePrice: salePriceController.text.trim().isEmpty
                        ? null
                        : _parseNumber(salePriceController.text),
                    vatRate: _parseNumber(vatRateController.text) ?? 20.0,
                    hasRecyclingFee: hasRecyclingFee,
                    recyclingFee: hasRecyclingFee && recyclingFeeController.text.trim().isNotEmpty
                        ? _parseNumber(recyclingFeeController.text)
                        : null,
                    defaultSupplierId: selectedSupplierId,
                    createdAt: DateTime.now().toIso8601String(),
                    updatedAt: DateTime.now().toIso8601String(),
                  );
                  
                  final materialId = await dbProvider.insertMaterial(material);
                  
                  // Reload materials
                  await _loadMaterials();
                  
                  // Select the newly created material
                  final newMaterial = _materials.firstWhere(
                    (m) => m.id == materialId,
                    orElse: () => _materials.first,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context, true);
                    setState(() {
                      _selectedMaterial = newMaterial;
                      // Update category to match the new material
                      _selectedCategory = newMaterial.category;
                      // Pre-fill prices if they were entered
                      if (purchasePriceWithoutVatController.text.isNotEmpty) {
                        _purchasePriceWithoutVatController.text = purchasePriceWithoutVatController.text;
                      }
                      if (purchasePriceWithVatController.text.isNotEmpty) {
                        _purchasePriceWithVatController.text = purchasePriceWithVatController.text;
                      }
                      if (vatRateController.text.isNotEmpty) {
                        _vatRateController.text = vatRateController.text;
                      }
                      if (selectedSupplierId != null) {
                        _selectedSupplier = _suppliers.firstWhere(
                          (s) => s.id == selectedSupplierId,
                          orElse: () => _suppliers.first,
                        );
                      }
                    });
                    
                    final mediaQuery = MediaQuery.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Materiál "${material.name}" bol vytvorený a vybratý'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => creating = false);
                  if (mounted) {
                    final mediaQuery = MediaQuery.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chyba pri vytváraní materiálu: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Vytvoriť a použiť'),
            ),
          ],
        ),
      ),
    );
    
    // Cleanup controllers
    nameController.dispose();
    pluController.dispose();
    eanController.dispose();
    unitController.dispose();
    minStockController.dispose();
    purchasePriceWithoutVatController.dispose();
    purchasePriceWithVatController.dispose();
    salePriceController.dispose();
    vatRateController.dispose();
  }
}


