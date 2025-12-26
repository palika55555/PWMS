import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';
import '../../services/warehouse_number_service.dart';

class CreateMaterialScreen extends StatefulWidget {
  final material_model.Material? materialToEdit;
  
  const CreateMaterialScreen({super.key, this.materialToEdit});

  @override
  State<CreateMaterialScreen> createState() => _CreateMaterialScreenState();
}

class _CreateMaterialScreenState extends State<CreateMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentStockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _unitController = TextEditingController(text: 'kg');
  final _pluCodeController = TextEditingController();
  final _eanCodeController = TextEditingController();
  final _warehouseNumberController = TextEditingController();
  final _purchasePriceWithoutVatController = TextEditingController();
  final _purchasePriceWithVatController = TextEditingController();
  final _salePriceWithoutVatController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _vatRateController = TextEditingController(text: '20');
  final _recyclingFeeController = TextEditingController();
  
  String _selectedType = 'cement';
  String _selectedCategory = 'warehouse'; // warehouse, production, retail
  int? _selectedSupplierId;
  List<Supplier> _suppliers = [];
  bool _loading = false;
  bool _loadingSuppliers = true;
  bool _hasRecyclingFee = false;

  final List<Map<String, String>> _materialTypes = [
    {'value': 'cement', 'label': 'Cement'},
    {'value': 'aggregate', 'label': 'Štrk'},
    {'value': 'water', 'label': 'Voda'},
    {'value': 'plasticizer', 'label': 'Plastifikátor'},
    {'value': 'other', 'label': 'Iné'},
  ];

  final List<Map<String, String>> _categories = [
    {'value': 'warehouse', 'label': 'Sklad', 'icon': 'warehouse', 'desc': 'Materiál na sklade'},
    {'value': 'production', 'label': 'Výroba', 'icon': 'factory', 'desc': 'Materiál pre výrobu'},
    {'value': 'retail', 'label': 'Maloobchod', 'icon': 'store', 'desc': 'Materiál na predaj'},
    {'value': 'overhead', 'label': 'Režijný materiál', 'icon': 'business', 'desc': 'Režijný materiál'},
  ];

  final List<String> _units = ['kg', 't', 'm³', 'l', 'ks'];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    if (widget.materialToEdit != null) {
      _loadMaterialData(); // Will be async now
    } else {
      // Generuj automatické poradové číslo pre nový produkt
      _generateWarehouseNumber();
    }
  }

  Future<void> _generateWarehouseNumber() async {
    if (widget.materialToEdit == null) {
      final warehouseNumberService = WarehouseNumberService();
      final warehouseNumber = await warehouseNumberService.generateWarehouseNumber();
      setState(() {
        _warehouseNumberController.text = warehouseNumber;
      });
    }
  }

  Future<void> _loadMaterialData() async {
    final material = widget.materialToEdit!;
    _nameController.text = material.name;
    _currentStockController.text = material.currentStock.toStringAsFixed(1);
    _minStockController.text = material.minStock.toStringAsFixed(1);
    // Validate that the unit exists in the dropdown items
    _unitController.text = _units.contains(material.unit) ? material.unit : 'kg';
    _pluCodeController.text = material.pluCode ?? '';
    _eanCodeController.text = material.eanCode ?? '';
    _warehouseNumberController.text = material.warehouseNumber ?? '';
    // Validate that the material type exists in the dropdown items
    final validTypes = _materialTypes.map((t) => t['value']!).toList();
    _selectedType = validTypes.contains(material.type) ? material.type : 'other';
    _selectedCategory = material.category;
    _selectedSupplierId = material.defaultSupplierId;
    _vatRateController.text = (material.vatRate ?? 20.0).toStringAsFixed(0);
    _hasRecyclingFee = material.hasRecyclingFee;
    if (material.recyclingFee != null) {
      _recyclingFeeController.text = material.recyclingFee!.toStringAsFixed(2);
    }
    
    // Load purchase prices from latest receipt (price history) if available
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final priceHistory = await dbProvider.getPriceHistory(materialId: material.id!);
    
    if (priceHistory.isNotEmpty) {
      // Get the most recent price history entry
      final latestPrice = priceHistory.first; // Already sorted by date DESC
      // Format price without VAT - use 4 decimal places for small values
      final priceWithoutVat = latestPrice.purchasePriceWithoutVat;
      if (priceWithoutVat < 0.01) {
        _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(4);
      } else {
        _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
      }
      // Format price with VAT - use 4 decimal places for small values
      final priceWithVat = latestPrice.purchasePriceWithVat;
      if (priceWithVat < 0.01) {
        _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(4);
      } else {
        _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
      }
    } else {
      // Fallback to average prices from material if no price history exists
      if (material.averagePurchasePriceWithoutVat != null) {
        final priceWithoutVat = material.averagePurchasePriceWithoutVat!;
        if (priceWithoutVat < 0.01) {
          _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(4);
        } else {
          _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
        }
      }
      if (material.averagePurchasePriceWithVat != null) {
        final priceWithVat = material.averagePurchasePriceWithVat!;
        if (priceWithVat < 0.01) {
          _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(4);
        } else {
          _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
        }
      }
    }
    
    if (material.salePrice != null) {
      _salePriceController.text = material.salePrice!.toStringAsFixed(2);
      // Calculate sale price without VAT from sale price with VAT
      final vatRate = material.vatRate ?? 20.0;
      final salePriceWithoutVat = material.salePrice! / (1 + vatRate / 100);
      _salePriceWithoutVatController.text = salePriceWithoutVat.toStringAsFixed(2);
    }
  }

  Future<void> _loadSuppliers() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final suppliers = await dbProvider.getSuppliers();
    setState(() {
      _suppliers = suppliers;
      _loadingSuppliers = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentStockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _pluCodeController.dispose();
    _eanCodeController.dispose();
    _warehouseNumberController.dispose();
    _purchasePriceWithoutVatController.dispose();
    _purchasePriceWithVatController.dispose();
    _salePriceWithoutVatController.dispose();
    _salePriceController.dispose();
    _vatRateController.dispose();
    _recyclingFeeController.dispose();
    super.dispose();
  }

  void _calculatePriceWithVat() {
    final priceWithoutVat = _parseNumber(_purchasePriceWithoutVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 20.0;
    if (priceWithoutVat != null) {
      final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
      _purchasePriceWithVatController.text = priceWithVat.toStringAsFixed(2);
    }
  }

  void _calculatePriceWithoutVat() {
    final priceWithVat = double.tryParse(_purchasePriceWithVatController.text.replaceAll(',', '.'));
    final vatRate = double.tryParse(_vatRateController.text.replaceAll(',', '.')) ?? 20.0;
    if (priceWithVat != null) {
      final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
      _purchasePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
    }
  }

  void _calculateSalePriceWithVat() {
    final priceWithoutVat = _parseNumber(_salePriceWithoutVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 20.0;
    if (priceWithoutVat != null) {
      final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
      _salePriceController.text = priceWithVat.toStringAsFixed(2);
    }
  }

  void _calculateSalePriceWithoutVat() {
    final priceWithVat = double.tryParse(_salePriceController.text.replaceAll(',', '.'));
    final vatRate = double.tryParse(_vatRateController.text.replaceAll(',', '.')) ?? 20.0;
    if (priceWithVat != null) {
      final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
      _salePriceWithoutVatController.text = priceWithoutVat.toStringAsFixed(2);
    }
  }

  // Helper function to parse number with comma support
  double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _createMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      var material = widget.materialToEdit?.copyWith(
        name: _nameController.text.trim(),
        type: _selectedType,
        category: _selectedCategory,
        unit: _unitController.text.trim(),
        currentStock: _parseNumber(_currentStockController.text) ?? 0,
        minStock: _parseNumber(_minStockController.text) ?? 0,
        pluCode: _pluCodeController.text.trim().isEmpty ? null : _pluCodeController.text.trim(),
        eanCode: _eanCodeController.text.trim().isEmpty ? null : _eanCodeController.text.trim(),
        averagePurchasePriceWithoutVat: _purchasePriceWithoutVatController.text.trim().isEmpty 
            ? null 
            : _parseNumber(_purchasePriceWithoutVatController.text),
        averagePurchasePriceWithVat: _purchasePriceWithVatController.text.trim().isEmpty 
            ? null 
            : _parseNumber(_purchasePriceWithVatController.text),
        salePrice: _salePriceController.text.trim().isEmpty 
            ? (_salePriceWithoutVatController.text.trim().isEmpty 
                ? null 
                : () {
                    final priceWithoutVat = _parseNumber(_salePriceWithoutVatController.text);
                    if (priceWithoutVat == null) return null;
                    final vatRate = _parseNumber(_vatRateController.text) ?? 20.0;
                    return priceWithoutVat * (1 + vatRate / 100);
                  }())
            : _parseNumber(_salePriceController.text),
        vatRate: _parseNumber(_vatRateController.text) ?? 20.0,
        hasRecyclingFee: _hasRecyclingFee,
        recyclingFee: _hasRecyclingFee && _recyclingFeeController.text.trim().isNotEmpty
            ? _parseNumber(_recyclingFeeController.text)
            : null,
        defaultSupplierId: _selectedSupplierId,
        warehouseNumber: _warehouseNumberController.text.trim().isEmpty 
            ? null
            : _warehouseNumberController.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
      ) ?? material_model.Material(
        name: _nameController.text.trim(),
        type: _selectedType,
        category: _selectedCategory,
        unit: _unitController.text.trim(),
        currentStock: _parseNumber(_currentStockController.text) ?? 0,
        minStock: _parseNumber(_minStockController.text) ?? 0,
        pluCode: _pluCodeController.text.trim().isEmpty ? null : _pluCodeController.text.trim(),
        eanCode: _eanCodeController.text.trim().isEmpty ? null : _eanCodeController.text.trim(),
        averagePurchasePriceWithoutVat: _purchasePriceWithoutVatController.text.trim().isEmpty 
            ? null 
            : _parseNumber(_purchasePriceWithoutVatController.text),
        averagePurchasePriceWithVat: _purchasePriceWithVatController.text.trim().isEmpty 
            ? null 
            : _parseNumber(_purchasePriceWithVatController.text),
        salePrice: _salePriceController.text.trim().isEmpty 
            ? (_salePriceWithoutVatController.text.trim().isEmpty 
                ? null 
                : () {
                    final priceWithoutVat = _parseNumber(_salePriceWithoutVatController.text);
                    if (priceWithoutVat == null) return null;
                    final vatRate = _parseNumber(_vatRateController.text) ?? 20.0;
                    return priceWithoutVat * (1 + vatRate / 100);
                  }())
            : _parseNumber(_salePriceController.text),
        vatRate: _parseNumber(_vatRateController.text) ?? 20.0,
        hasRecyclingFee: _hasRecyclingFee,
        recyclingFee: _hasRecyclingFee && _recyclingFeeController.text.trim().isNotEmpty
            ? _parseNumber(_recyclingFeeController.text)
            : null,
        defaultSupplierId: _selectedSupplierId,
        warehouseNumber: _warehouseNumberController.text.trim().isEmpty 
            ? null
            : _warehouseNumberController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      // Ak nie je zadané poradové číslo, generuj ho automaticky
      String? warehouseNumber = material.warehouseNumber;
      if (warehouseNumber == null || warehouseNumber.isEmpty) {
        final warehouseNumberService = WarehouseNumberService();
        warehouseNumber = await warehouseNumberService.generateWarehouseNumber();
        material = material.copyWith(warehouseNumber: warehouseNumber);
      }

      if (widget.materialToEdit != null) {
        await dbProvider.updateMaterial(material);
        if (mounted) {
          final mediaQueryTop = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Skladová položka bola úspešne upravená'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: mediaQueryTop.padding.top + 16,
            left: 16,
            right: 16,
          ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await dbProvider.insertMaterial(material);
        if (mounted) {
          final mediaQueryTop = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Skladová položka bola úspešne vytvorená'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: mediaQueryTop.padding.top + 16,
            left: 16,
            right: 16,
          ),
            ),
          );
          Navigator.pop(context, true);
        }
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.materialToEdit != null ? 'Upraviť skladovú položku' : 'Nová skladová položka'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade50,
                      Colors.green.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_box,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.materialToEdit != null 
                                ? 'Upraviť skladovú položku'
                                : 'Vytvoriť skladovú položku',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.materialToEdit != null
                                ? 'Upravte údaje o skladovej položke'
                                : 'Vyplňte údaje o novej skladovej položke',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Material name
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Názov materiálu *',
                    hintText: 'Napríklad: Cement CEM I 42.5',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Zadajte názov materiálu';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Material type
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Typ materiálu *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _materialTypes.map((type) {
                    return DropdownMenuItem(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategória použitia *',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._categories.map((category) {
                      final isSelected = _selectedCategory == category['value'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category['value']!;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Colors.blue.shade50 
                                  : Colors.grey.shade50,
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.blue.shade700 
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category['icon']!),
                                  color: isSelected 
                                      ? Colors.blue.shade700 
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category['label']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected 
                                              ? Colors.blue.shade900 
                                              : Colors.grey.shade900,
                                        ),
                                      ),
                                      Text(
                                        category['desc']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.blue.shade700,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Unit
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: _unitController.text,
                  decoration: const InputDecoration(
                    labelText: 'Jednotka *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: _units.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _unitController.text = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current stock
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _currentStockController,
                  decoration: InputDecoration(
                    labelText: 'Aktuálny stav *',
                    hintText: '0',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.inventory),
                    suffixText: _unitController.text,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Zadajte aktuálny stav';
                    }
                    if (_parseNumber(value) == null) {
                      return 'Zadajte platné číslo';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.contains(',')) {
                      final newValue = value.replaceAll(',', '.');
                      _currentStockController.value = TextEditingValue(
                        text: newValue,
                        selection: TextSelection.collapsed(offset: newValue.length),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Minimum stock
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _minStockController,
                  decoration: InputDecoration(
                    labelText: 'Minimálny stav *',
                    hintText: '0',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.warning),
                    suffixText: _unitController.text,
                    helperText: 'Pri dosiahnutí tohto stavu sa zobrazí upozornenie',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Zadajte minimálny stav';
                    }
                    if (_parseNumber(value) == null) {
                      return 'Zadajte platné číslo';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.contains(',')) {
                      final newValue = value.replaceAll(',', '.');
                      _minStockController.value = TextEditingValue(
                        text: newValue,
                        selection: TextSelection.collapsed(offset: newValue.length),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // PLU Code
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _pluCodeController,
                  decoration: const InputDecoration(
                    labelText: 'PLU kód',
                    hintText: 'Price Look-Up kód',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // EAN Code
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _eanCodeController,
                  decoration: const InputDecoration(
                    labelText: 'EAN kód',
                    hintText: 'European Article Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Warehouse Number
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _warehouseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Poradové číslo na sklade',
                    hintText: 'Číslo produktu na sklade',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Supplier
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingSuppliers
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int?>(
                        value: _selectedSupplierId,
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
                          setState(() {
                            _selectedSupplierId = value;
                          });
                        },
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
                          'Ceny',
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
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculatePriceWithVat();
                        _calculateSalePriceWithVat();
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Purchase price without VAT
                    TextFormField(
                      controller: _purchasePriceWithoutVatController,
                      decoration: const InputDecoration(
                        labelText: 'Nákupná cena bez DPH (€)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_cart),
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
                      decoration: const InputDecoration(
                        labelText: 'Nákupná cena s DPH (€)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_bag),
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
                    const SizedBox(height: 16),
                    
                    // Sale price without VAT
                    TextFormField(
                      controller: _salePriceWithoutVatController,
                      decoration: const InputDecoration(
                        labelText: 'Predajná cena bez DPH (€)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sell),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        if (value.contains(',')) {
                          final newValue = value.replaceAll(',', '.');
                          _salePriceWithoutVatController.value = TextEditingValue(
                            text: newValue,
                            selection: TextSelection.collapsed(offset: newValue.length),
                          );
                        }
                        _calculateSalePriceWithVat();
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Sale price with VAT
                    TextFormField(
                      controller: _salePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Predajná cena s DPH (€)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sell),
                        helperText: 'Cena pri predaji tovaru',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        if (value.contains(',')) {
                          final newValue = value.replaceAll(',', '.');
                          _salePriceController.value = TextEditingValue(
                            text: newValue,
                            selection: TextSelection.collapsed(offset: newValue.length),
                          );
                        }
                        _calculateSalePriceWithoutVat();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recycling fee section
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade50,
                      Colors.teal.shade100,
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
                        Icon(Icons.recycling, color: Colors.teal.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Recyklačný poplatok',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _hasRecyclingFee,
                      onChanged: (value) {
                        setState(() {
                          _hasRecyclingFee = value ?? false;
                          if (!_hasRecyclingFee) {
                            _recyclingFeeController.clear();
                          }
                        });
                      },
                      title: const Text('Má recyklačný poplatok'),
                      subtitle: const Text('Označte, ak produkt má recyklačný poplatok'),
                      activeColor: Colors.teal.shade700,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_hasRecyclingFee) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _recyclingFeeController,
                        decoration: const InputDecoration(
                          labelText: 'Suma recyklačného poplatku (€)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.euro),
                          helperText: 'Zadajte sumu recyklačného poplatku (môžete použiť čiarku alebo bodku)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (_hasRecyclingFee && (value == null || value.isEmpty)) {
                            return 'Zadajte sumu recyklačného poplatku';
                          }
                          if (_hasRecyclingFee && value != null && value.isNotEmpty) {
                            final parsed = _parseNumber(value);
                            if (parsed == null || parsed < 0) {
                              return 'Zadajte platnú sumu';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Automaticky konvertuj čiarku na bodku pri písaní
                          if (value.contains(',')) {
                            final newValue = value.replaceAll(',', '.');
                            _recyclingFeeController.value = TextEditingValue(
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
            ),
            const SizedBox(height: 32),

            // Create button
            ElevatedButton(
              onPressed: _loading ? null : _createMaterial,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle),
                        const SizedBox(width: 8),
                        Text(
                          widget.materialToEdit != null
                              ? 'Uložiť zmeny'
                              : 'Vytvoriť skladovú položku',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'warehouse':
        return Icons.warehouse;
      case 'factory':
        return Icons.factory;
      case 'store':
        return Icons.store;
      default:
        return Icons.category;
    }
  }
}


