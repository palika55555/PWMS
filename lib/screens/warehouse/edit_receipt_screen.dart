import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';

class EditReceiptScreen extends StatefulWidget {
  final StockMovement receipt;
  
  const EditReceiptScreen({super.key, required this.receipt});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
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
  final _vatRateController = TextEditingController();
  DateTime _receiptDate = DateTime.now();
  DateTime? _deliveryDate;
  DateTime? _expirationDate;
  String _selectedCategory = 'warehouse';
  List<material_model.Material> _materials = [];
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _loading = true;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _isApproved = widget.receipt.status == 'approved';
    _loadData();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final suppliers = await dbProvider.getSuppliers();
    
    // Find selected material
    material_model.Material? material;
    if (widget.receipt.materialId != null) {
      material = materials.firstWhere(
        (m) => m.id == widget.receipt.materialId,
        orElse: () => materials.first,
      );
    }
    
    // Find selected supplier
    Supplier? supplier;
    if (widget.receipt.supplierId != null) {
      supplier = suppliers.firstWhere(
        (s) => s.id == widget.receipt.supplierId,
        orElse: () => suppliers.first,
      );
    }
    
    // Parse notes to extract category if present
    String category = 'warehouse';
    String notes = widget.receipt.notes ?? '';
    if (notes.contains('Kategória:')) {
      final categoryMatch = RegExp(r'Kategória:\s*(\w+)').firstMatch(notes);
      if (categoryMatch != null) {
        final categoryName = categoryMatch.group(1)!;
        switch (categoryName) {
          case 'Sklad':
            category = 'warehouse';
            break;
          case 'Výroba':
            category = 'production';
            break;
          case 'Maloobchod':
            category = 'retail';
            break;
          case 'Režijný':
            category = 'overhead';
            break;
        }
        // Remove category from notes
        notes = notes.replaceAll(RegExp(r'Kategória:\s*\w+\.?\s*'), '').trim();
      }
    }
    
    // Load prices from receipt, or try to get from price history if not available
    double? priceWithoutVat = widget.receipt.purchasePriceWithoutVat;
    double? priceWithVat = widget.receipt.purchasePriceWithVat;
    double? vatRate = widget.receipt.vatRate;
    
    // If prices are not in receipt, try to get from price history
    if ((priceWithoutVat == null || priceWithVat == null) && material?.id != null) {
      final receiptDate = DateTime.parse(widget.receipt.movementDate);
      final priceHistoryList = await dbProvider.getPriceHistory(
        materialId: material!.id,
        supplierId: supplier?.id,
        fromDate: receiptDate.subtract(const Duration(days: 1)),
        toDate: receiptDate.add(const Duration(days: 1)),
      );
      
      // Find price history entry with matching document number or closest date
      PriceHistory? matchingPriceHistory;
      if (priceHistoryList.isNotEmpty) {
        if (widget.receipt.documentNumber != null && widget.receipt.documentNumber!.isNotEmpty) {
          try {
            matchingPriceHistory = priceHistoryList.firstWhere(
              (ph) => ph.documentNumber == widget.receipt.documentNumber,
            );
          } catch (e) {
            // No matching document number, use first entry
            matchingPriceHistory = priceHistoryList.first;
          }
        } else {
          matchingPriceHistory = priceHistoryList.first;
        }
      }
      
      if (matchingPriceHistory != null) {
        if (priceWithoutVat == null) {
          priceWithoutVat = matchingPriceHistory.purchasePriceWithoutVat;
        }
        if (priceWithVat == null) {
          priceWithVat = matchingPriceHistory.purchasePriceWithVat;
        }
        if (vatRate == null) {
          vatRate = matchingPriceHistory.vatRate;
        }
      }
    }
    
    setState(() {
      _materials = materials;
      _suppliers = suppliers;
      _selectedMaterial = material;
      _selectedSupplier = supplier;
      _selectedCategory = category;
      
      // Fill form fields
      _quantityController.text = widget.receipt.quantity.toString();
      _documentNumberController.text = widget.receipt.documentNumber ?? '';
      _supplierController.text = widget.receipt.supplierName ?? '';
      _locationController.text = widget.receipt.location ?? '';
      _notesController.text = notes;
      _productNoteController.text = widget.receipt.productNote ?? '';
      
      // Format prices for display
      _purchasePriceWithoutVatController.text = 
          priceWithoutVat != null ? _formatPurchasePrice(priceWithoutVat) : '';
      _purchasePriceWithVatController.text = 
          priceWithVat != null ? _formatPurchasePrice(priceWithVat) : '';
      _vatRateController.text = vatRate != null ? vatRate.toStringAsFixed(2) : '20';
      
      // Parse dates
      _receiptDate = DateTime.parse(widget.receipt.movementDate);
      _deliveryDate = widget.receipt.deliveryDate != null
          ? DateTime.parse(widget.receipt.deliveryDate!)
          : null;
      _expirationDate = widget.receipt.expirationDate != null
          ? DateTime.parse(widget.receipt.expirationDate!)
          : null;
      
      _loading = false;
    });
  }

  void _calculatePriceWithVat() {
    final priceWithoutVat = double.tryParse(_purchasePriceWithoutVatController.text);
    final vatRate = double.tryParse(_vatRateController.text) ?? 0.0;
    if (priceWithoutVat != null && priceWithoutVat > 0) {
      if (vatRate == 0) {
        _purchasePriceWithVatController.text = _formatPurchasePrice(priceWithoutVat);
      } else {
        final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
        _purchasePriceWithVatController.text = _formatPurchasePrice(priceWithVat);
      }
    }
  }

  void _calculatePriceWithoutVat() {
    final priceWithVat = double.tryParse(_purchasePriceWithVatController.text);
    final vatRate = double.tryParse(_vatRateController.text) ?? 0.0;
    if (priceWithVat != null && priceWithVat > 0) {
      if (vatRate == 0) {
        _purchasePriceWithoutVatController.text = _formatPurchasePrice(priceWithVat);
      } else {
        final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
        _purchasePriceWithoutVatController.text = _formatPurchasePrice(priceWithoutVat);
      }
    }
  }

  // Helper function to format purchase price with 4 decimal places for small values
  String _formatPurchasePrice(double? price) {
    if (price == null) return '';
    if (price == 0) return '0.0000';
    
    // For very small prices (less than 0.01), show 4 decimal places
    if (price < 0.01) {
      return price.toStringAsFixed(4);
    }
    // For normal prices, show 2 decimal places
    return price.toStringAsFixed(2);
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

    if (_isApproved) {
      // Show warning for approved receipts
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upraviť schválenú príjemku'),
          content: const Text(
            'Táto príjemka je už schválená. Úprava zmení stav skladu podľa rozdielu medzi pôvodnými a novými hodnotami.\n\n'
            'Chcete pokračovať?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Upraviť'),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        return;
      }
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final quantity = double.parse(_quantityController.text);
    final priceWithoutVat = _purchasePriceWithoutVatController.text.trim().isEmpty
        ? null
        : double.tryParse(_purchasePriceWithoutVatController.text);
    final priceWithVat = _purchasePriceWithVatController.text.trim().isEmpty
        ? null
        : double.tryParse(_purchasePriceWithVatController.text);
    final vatRate = double.tryParse(_vatRateController.text) ?? 20.0;
    
    final updatedMovement = widget.receipt.copyWith(
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
      movementDate: DateFormat('yyyy-MM-dd').format(_receiptDate),
      deliveryDate: _deliveryDate != null ? DateFormat('yyyy-MM-dd').format(_deliveryDate!) : null,
    );

    try {
      // Update material category if changed
      if (_selectedMaterial!.category != _selectedCategory) {
        final updatedMaterial = _selectedMaterial!.copyWith(
          category: _selectedCategory,
          updatedAt: DateTime.now().toIso8601String(),
        );
        await dbProvider.updateMaterial(updatedMaterial);
      }
      
      await dbProvider.updateStockMovement(updatedMovement);
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isApproved 
                ? 'Schválená príjemka bola úspešne upravená a stav skladu bol aktualizovaný'
                : 'Príjemka bola úspešne upravená'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final mediaQueryTop = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: mediaQueryTop.padding.top + 16,
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
        title: Text(_isApproved ? 'Upraviť schválenú príjemku' : 'Upraviť príjemku'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Warning banner for approved receipts
            if (_isApproved)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Táto príjemka je schválená. Úprava automaticky upraví stav skladu.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Material selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Materiál *',
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
                          if (material != null) {
                            _selectedCategory = material.category;
                          }
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
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculatePriceWithoutVat();
                      },
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
              icon: const Icon(Icons.save),
              label: const Text('Uložiť zmeny'),
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




