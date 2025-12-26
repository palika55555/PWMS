import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as material_widget show Material;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import '../../models/price_history.dart';
import '../../services/receipt_number_service.dart';
import '../../services/warehouse_number_service.dart';
import '../../screens/qr_code/qr_code_screen.dart';
import 'create_material_screen.dart';

// Intent class for keyboard shortcut
class _AddItemIntent extends Intent {
  const _AddItemIntent();
}

class BulkReceiptItem {
  material_model.Material? material;
  double quantity = 0;
  double? purchasePriceWithoutVat;
  double? purchasePriceWithVat;
  double vatRate = 20.0;
  String category = 'warehouse'; // warehouse, production, retail
  String? documentNumber;
  String? location;
  String? notes;

  BulkReceiptItem();

  Map<String, dynamic> toJson() {
    return {
      'materialId': material?.id,
      'quantity': quantity,
      'purchasePriceWithoutVat': purchasePriceWithoutVat,
      'purchasePriceWithVat': purchasePriceWithVat,
      'vatRate': vatRate,
      'category': category,
      'documentNumber': documentNumber,
      'location': location,
      'notes': notes,
    };
  }

  factory BulkReceiptItem.fromJson(Map<String, dynamic> json) {
    final item = BulkReceiptItem();
    item.quantity = (json['quantity'] as num?)?.toDouble() ?? 0;
    item.purchasePriceWithoutVat = (json['purchasePriceWithoutVat'] as num?)?.toDouble();
    item.purchasePriceWithVat = (json['purchasePriceWithVat'] as num?)?.toDouble();
    item.vatRate = (json['vatRate'] as num?)?.toDouble() ?? 20.0;
    item.category = json['category'] as String? ?? 'warehouse';
    item.documentNumber = json['documentNumber'] as String?;
    item.location = json['location'] as String?;
    item.notes = json['notes'] as String?;
    return item;
  }
}

class BulkReceiptDraft {
  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Supplier? selectedSupplier;
  final String? supplierName;
  final int? warehouseId;
  final String? deliveryNoteNumber;
  final DateTime receiptDate;
  final DateTime? deliveryDate;
  final double globalVatRate;
  final List<BulkReceiptItem> items;

  BulkReceiptDraft({
    required this.id,
    this.name,
    required this.createdAt,
    this.updatedAt,
    this.selectedSupplier,
    this.supplierName,
    this.warehouseId,
    this.deliveryNoteNumber,
    required this.receiptDate,
    this.deliveryDate,
    required this.globalVatRate,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'supplierId': selectedSupplier?.id,
      'supplierName': supplierName,
      'warehouseId': warehouseId,
      'deliveryNoteNumber': deliveryNoteNumber,
      'receiptDate': receiptDate.toIso8601String(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'globalVatRate': globalVatRate,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory BulkReceiptDraft.fromJson(Map<String, dynamic> json, {Supplier? supplier}) {
    return BulkReceiptDraft(
      id: json['id'] as String,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      selectedSupplier: supplier,
      supplierName: json['supplierName'] as String?,
      warehouseId: json['warehouseId'] as int?,
      deliveryNoteNumber: json['deliveryNoteNumber'] as String?,
      receiptDate: DateTime.parse(json['receiptDate'] as String),
      deliveryDate: json['deliveryDate'] != null ? DateTime.parse(json['deliveryDate'] as String) : null,
      globalVatRate: (json['globalVatRate'] as num?)?.toDouble() ?? 20.0,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => BulkReceiptItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class BulkReceiptScreen extends StatefulWidget {
  const BulkReceiptScreen({super.key});

  @override
  State<BulkReceiptScreen> createState() => _BulkReceiptScreenState();
}

class _BulkReceiptScreenState extends State<BulkReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<BulkReceiptItem> _items = [];
  Supplier? _selectedSupplier;
  final _supplierController = TextEditingController();
  Warehouse? _selectedWarehouse;
  int? _draftWarehouseId;
  final _deliveryNoteNumberController = TextEditingController();
  DateTime _receiptDate = DateTime.now();
  DateTime? _deliveryDate;
  List<material_model.Material> _materials = [];
  List<Supplier> _suppliers = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  bool _saving = false;
  double _globalVatRate = 20.0; // Hromadné nastavenie DPH
  final _focusNode = FocusNode();
  String? _currentDraftId; // ID aktuálneho draftu, ak existuje
  final List<double> _commonQuantities = [1, 5, 10, 25, 50, 100]; // Rýchle množstvá

  @override
  void initState() {
    super.initState();
    _loadData();
    _items.add(BulkReceiptItem()..vatRate = _globalVatRate); // Start with one empty item
    _checkForDrafts();
  }

  Future<void> _checkForDrafts() async {
    final drafts = await _loadDrafts();
    if (drafts.isNotEmpty && mounted) {
      final selectedDraft = await showDialog<BulkReceiptDraft>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rozpracované príjmy'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Text(
            'Našli sa ${drafts.length} rozpracovan${drafts.length == 1 ? 'ý' : 'é'} príjem${drafts.length == 1 ? '' : 'y'}. '
            'Chcete pokračovať v rozpracovanom príjme?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zavrieť'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Začať nový'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, drafts.first),
              child: const Text('Pokračovať'),
            ),
          ],
        ),
      );
      
      if (selectedDraft != null) {
        await _loadDraft(selectedDraft);
        // Scroll to top after loading draft
        if (mounted) {
          // Trigger rebuild to show loaded data
          setState(() {});
        }
      }
    }
  }

  Future<List<BulkReceiptDraft>> _loadDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getStringList('bulk_receipt_drafts') ?? [];
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final suppliers = await dbProvider.getSuppliers();
      
      final loadedDrafts = <BulkReceiptDraft>[];
      for (final jsonStr in draftsJson) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final supplierId = json['supplierId'] as int?;
          Supplier? supplier;
          if (supplierId != null && suppliers.isNotEmpty) {
            try {
              supplier = suppliers.firstWhere((s) => s.id == supplierId);
            } catch (e) {
              supplier = null;
            }
          }
          loadedDrafts.add(BulkReceiptDraft.fromJson(json, supplier: supplier));
        } catch (e) {
          // Skip invalid drafts
          continue;
        }
      }
      loadedDrafts.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
      return loadedDrafts;
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadDraft(BulkReceiptDraft draft) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    
    // Aktualizuj _materials zoznam
    final uniqueMaterials = <int, material_model.Material>{};
    for (final material in materials) {
      if (material.id != null) {
        uniqueMaterials[material.id!] = material;
      }
    }
    
    // Načítaj položky a priraď materiály
    // Musíme načítať items z JSON, aby sme získali materialId
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = prefs.getStringList('bulk_receipt_drafts') ?? [];
    Map<String, dynamic>? draftJson;
    for (final jsonStr in draftsJson) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (json['id'] as String == draft.id) {
          draftJson = json;
          break;
        }
      } catch (e) {
        continue;
      }
    }
    
    final List<BulkReceiptItem> loadedItems = [];
    if (draftJson != null && draftJson['items'] != null) {
      final itemsJson = draftJson['items'] as List<dynamic>;
      for (final itemJson in itemsJson) {
        final itemMap = itemJson as Map<String, dynamic>;
        final loadedItem = BulkReceiptItem()
          ..quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0
          ..purchasePriceWithoutVat = (itemMap['purchasePriceWithoutVat'] as num?)?.toDouble()
          ..purchasePriceWithVat = (itemMap['purchasePriceWithVat'] as num?)?.toDouble()
          ..vatRate = (itemMap['vatRate'] as num?)?.toDouble() ?? 20.0
          ..category = itemMap['category'] as String? ?? 'warehouse'
          ..documentNumber = itemMap['documentNumber'] as String?
          ..location = itemMap['location'] as String?
          ..notes = itemMap['notes'] as String?;
        
        // Priraď materiál podľa ID z JSON
        final materialId = itemMap['materialId'] as int?;
        if (materialId != null && uniqueMaterials.containsKey(materialId)) {
          loadedItem.material = uniqueMaterials[materialId];
        } else {
          loadedItem.material = null;
        }
        loadedItems.add(loadedItem);
      }
    } else {
      // Fallback - použij items z draft objektu (ak material už existuje)
      for (final item in draft.items) {
        final loadedItem = BulkReceiptItem()
          ..quantity = item.quantity
          ..purchasePriceWithoutVat = item.purchasePriceWithoutVat
          ..purchasePriceWithVat = item.purchasePriceWithVat
          ..vatRate = item.vatRate
          ..category = item.category
          ..documentNumber = item.documentNumber
          ..location = item.location
          ..notes = item.notes;
        
        final materialId = item.material?.id;
        if (materialId != null && uniqueMaterials.containsKey(materialId)) {
          loadedItem.material = uniqueMaterials[materialId];
        } else {
          loadedItem.material = null;
        }
        loadedItems.add(loadedItem);
      }
    }
    
    if (mounted) {
      // Načítaj suppliers znovu, aby sme mali aktuálny zoznam
      final suppliers = await dbProvider.getSuppliers();
      
      setState(() {
        // Aktualizuj _materials zoznam
        _materials = uniqueMaterials.values.toList();
        _suppliers = suppliers;
        
        _currentDraftId = draft.id;
        
        // Nájdi správneho dodávateľa v _suppliers liste podľa ID
        if (draft.selectedSupplier != null && draft.selectedSupplier!.id != null) {
          try {
            _selectedSupplier = _suppliers.firstWhere(
              (s) => s.id == draft.selectedSupplier!.id,
            );
          } catch (e) {
            // Dodávateľ sa nenašiel v zozname - nastav na null
            _selectedSupplier = null;
          }
        } else {
          _selectedSupplier = null;
        }
        
        _supplierController.text = draft.supplierName ?? '';
        _deliveryNoteNumberController.text = draft.deliveryNoteNumber ?? '';
        _receiptDate = draft.receiptDate;
        _deliveryDate = draft.deliveryDate;
        _globalVatRate = draft.globalVatRate;
        
        _items.clear();
        _items.addAll(loadedItems);
        
        if (_items.isEmpty) {
          _items.add(BulkReceiptItem()..vatRate = _globalVatRate);
        }
      });
      
      // Po načítaní draftu nastav hodnoty v Autocomplete polích
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Toto spôsobí, že sa Autocomplete widgety znovu vytvoria s novými hodnotami
          });
        }
      });
    }
  }

  Future<void> _saveDraft() async {
    try {
      // Ask for draft name if new draft
      String? draftName;
      if (_currentDraftId == null) {
        final nameController = TextEditingController();
        final defaultName = 'Príjem ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}';
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pomenovať draft'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Názov draftu',
                hintText: defaultName,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrušiť'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, nameController.text.trim().isEmpty 
                    ? defaultName
                    : nameController.text.trim()),
                child: const Text('Uložiť'),
              ),
            ],
          ),
        );
        if (result == null) return; // User cancelled
        draftName = result;
      } else {
        // Get existing draft name
        final drafts = await _loadDrafts();
        final existingDraft = drafts.firstWhere(
          (d) => d.id == _currentDraftId,
          orElse: () => BulkReceiptDraft(
            id: _currentDraftId!,
            name: null,
            createdAt: DateTime.now(),
            receiptDate: _receiptDate,
            globalVatRate: _globalVatRate,
            items: [],
          ),
        );
        draftName = existingDraft.name;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final drafts = await _loadDrafts();
      
      final draft = BulkReceiptDraft(
        id: _currentDraftId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: draftName,
        createdAt: _currentDraftId != null 
            ? drafts.firstWhere((d) => d.id == _currentDraftId, orElse: () => drafts.first).createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
        selectedSupplier: _selectedSupplier,
        supplierName: _supplierController.text.isEmpty ? null : _supplierController.text,
        deliveryNoteNumber: _deliveryNoteNumberController.text.isEmpty 
            ? null 
            : _deliveryNoteNumberController.text,
        receiptDate: _receiptDate,
        deliveryDate: _deliveryDate,
        globalVatRate: _globalVatRate,
        items: _items,
      );
      
      // Odstráň starý draft, ak existuje
      if (_currentDraftId != null) {
        drafts.removeWhere((d) => d.id == _currentDraftId);
      }
      
      // Pridaj nový/aktualizovaný draft
      drafts.insert(0, draft);
      
      // Ulož maximálne 10 draftov
      if (drafts.length > 10) {
        drafts.removeRange(10, drafts.length);
      }
      
      // Ulož do SharedPreferences
      final draftsJson = drafts.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList('bulk_receipt_drafts', draftsJson);
      
      setState(() {
        _currentDraftId = draft.id;
      });
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rozpracovaný príjem bol uložený'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní draftu: $e'),
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

  Future<void> _deleteDraft() async {
    if (_currentDraftId == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await _loadDrafts();
      drafts.removeWhere((d) => d.id == _currentDraftId);
      
      final draftsJson = drafts.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList('bulk_receipt_drafts', draftsJson);
      
      setState(() {
        _currentDraftId = null;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final suppliers = await dbProvider.getSuppliers();
    final warehouses = await dbProvider.getWarehouses(activeOnly: true);
    setState(() {
      // Odstráň duplikáty podľa ID
      final uniqueMaterials = <int, material_model.Material>{};
      for (final material in materials) {
        if (material.id != null) {
          uniqueMaterials[material.id!] = material;
        }
      }
      _materials = uniqueMaterials.values.toList();
      _suppliers = suppliers;
      _warehouses = warehouses;
      _loading = false;
    });
  }

  void _addItem() {
    setState(() {
      _items.add(BulkReceiptItem()..vatRate = _globalVatRate);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _calculatePriceWithVat(int index) {
    final item = _items[index];
    final priceWithoutVat = item.purchasePriceWithoutVat;
    if (priceWithoutVat != null && priceWithoutVat > 0) {
      if (item.vatRate == 0) {
        item.purchasePriceWithVat = priceWithoutVat;
      } else {
        item.purchasePriceWithVat = priceWithoutVat * (1 + item.vatRate / 100);
      }
    }
  }

  void _calculatePriceWithoutVat(int index) {
    final item = _items[index];
    final priceWithVat = item.purchasePriceWithVat;
    if (priceWithVat != null && priceWithVat > 0) {
      if (item.vatRate == 0) {
        item.purchasePriceWithoutVat = priceWithVat;
      } else {
        item.purchasePriceWithoutVat = priceWithVat / (1 + item.vatRate / 100);
      }
    }
  }

  // Helper function to parse number with comma support
  double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
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

  // Helper function to format sale price with 2 decimal places
  String _formatSalePrice(double? price) {
    if (price == null) return '';
    if (price == 0) return '0.00';
    return price.toStringAsFixed(2);
  }

  // Legacy method for backward compatibility - uses purchase price formatting
  String _formatPrice(double? price) {
    return _formatPurchasePrice(price);
  }

  // Get last purchase price for material
  Future<PriceHistory?> _getLastPurchasePrice(int materialId) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final priceHistory = await dbProvider.getPriceHistory(materialId: materialId);
    if (priceHistory.isNotEmpty) {
      return priceHistory.first; // Already sorted by date DESC
    }
    return null;
  }

  // Calculate totals
  double _calculateTotalWithoutVat() {
    double total = 0;
    for (final item in _items) {
      if (item.material != null && item.quantity > 0 && item.purchasePriceWithoutVat != null) {
        total += item.purchasePriceWithoutVat! * item.quantity;
      }
    }
    return total;
  }

  double _calculateTotalWithVat() {
    double total = 0;
    for (final item in _items) {
      if (item.material != null && item.quantity > 0) {
        if (item.purchasePriceWithVat != null) {
          total += item.purchasePriceWithVat! * item.quantity;
        } else if (item.purchasePriceWithoutVat != null) {
          total += item.purchasePriceWithoutVat! * (1 + item.vatRate / 100) * item.quantity;
        }
      }
    }
    return total;
  }

  double _calculateTotalVat() {
    return _calculateTotalWithVat() - _calculateTotalWithoutVat();
  }

  double _calculateAveragePricePerUnit() {
    double totalValue = _calculateTotalWithVat();
    double totalQuantity = 0;
    for (final item in _items) {
      if (item.material != null && item.quantity > 0) {
        totalQuantity += item.quantity;
      }
    }
    if (totalQuantity > 0) {
      return totalValue / totalQuantity;
    }
    return 0;
  }

  Future<void> _editMaterial(material_model.Material material) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaterialScreen(materialToEdit: material),
      ),
    );
    if (result == true) {
      // Reload materials to get updated data
      await _loadData();
      // Update the item's material reference if it was edited
      setState(() {
        for (var item in _items) {
          if (item.material?.id == material.id) {
            final matchingMaterials = _materials.where((m) => m.id == material.id);
            if (matchingMaterials.isNotEmpty) {
              item.material = matchingMaterials.first;
            } else {
              // Material was deleted, clear the reference
              item.material = null;
            }
          }
        }
      });
    }
  }

  Future<void> _saveBulkReceipt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedWarehouse == null) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Prosím vyberte sklad'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    // Validate that at least one item has material and quantity
    final validItems = _items.where((item) => 
      item.material != null && item.quantity > 0
    ).toList();

    if (validItems.isEmpty) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pridajte aspoň jednu položku s materiálom a množstvom'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final dateStr = DateFormat('yyyy-MM-dd').format(_receiptDate);
      final supplierName = _selectedSupplier?.name ?? 
          (_supplierController.text.isEmpty ? null : _supplierController.text);

      // Generate one receipt number for all items in bulk receipt
      final receiptNumberService = ReceiptNumberService();
      final receiptNumber = await receiptNumberService.generateReceiptNumber();

      // Get delivery note number from common field
      final deliveryNoteNumber = _deliveryNoteNumberController.text.trim();
      
      for (final item in validItems) {
        // Update material category and VAT rate if changed
        bool materialNeedsUpdate = false;
        material_model.Material updatedMaterial = item.material!;
        
        if (item.material!.category != item.category) {
          materialNeedsUpdate = true;
          updatedMaterial = updatedMaterial.copyWith(
            category: item.category,
            updatedAt: DateTime.now().toIso8601String(),
          );
        }
        
        // Update VAT rate in material if VAT rate is provided in receipt
        // Update even if no prices are provided, as VAT rate is important for the material
        if (item.material!.vatRate != item.vatRate) {
          materialNeedsUpdate = true;
          updatedMaterial = updatedMaterial.copyWith(
            vatRate: item.vatRate,
            updatedAt: DateTime.now().toIso8601String(),
          );
        }
        
        if (materialNeedsUpdate) {
          await dbProvider.updateMaterial(updatedMaterial);
        }
        
        // Build notes with category info
        String? notes = item.notes?.isEmpty ?? true ? null : item.notes;
        if (notes != null) {
          notes = 'Kategória: ${_getCategoryName(item.category)}. $notes';
        } else {
          notes = 'Kategória: ${_getCategoryName(item.category)}';
        }
        
        // Use item-specific document number if provided, otherwise use common delivery note number
        final finalDocumentNumber = (item.documentNumber?.isNotEmpty ?? false) 
            ? item.documentNumber 
            : (deliveryNoteNumber.isNotEmpty ? deliveryNoteNumber : null);
        
        final movement = StockMovement(
          movementType: 'receipt',
          materialId: item.material!.id!,
          quantity: item.quantity,
          unit: item.material!.unit,
          documentNumber: finalDocumentNumber,
          receiptNumber: receiptNumber, // Use the same receipt number for all items
          supplierName: supplierName,
          location: item.location?.isEmpty ?? true ? null : item.location,
          notes: notes,
          purchasePriceWithoutVat: item.purchasePriceWithoutVat,
          purchasePriceWithVat: item.purchasePriceWithVat,
          vatRate: (item.purchasePriceWithoutVat != null || item.purchasePriceWithVat != null) 
              ? item.vatRate 
              : null,
          supplierId: _selectedSupplier?.id,
          warehouseId: _selectedWarehouse?.id,
          movementDate: dateStr,
          deliveryDate: _deliveryDate != null ? DateFormat('yyyy-MM-dd').format(_deliveryDate!) : null,
          createdBy: 'Current User', // TODO: Get from auth
          createdAt: DateTime.now().toIso8601String(),
        );

        await dbProvider.insertStockMovement(movement);

        // Price history will be created when receipt is approved
        // This ensures only approved receipts are added to price history
      }

      // Vymazať draft po úspešnom uložení
      if (_currentDraftId != null) {
        await _deleteDraft();
      }

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hromadný príjem ${validItems.length} položiek bol úspešne zaznamenaný'),
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _deliveryNoteNumberController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.period, control: true): _AddItemIntent(),
      },
      child: Actions(
        actions: {
          _AddItemIntent: CallbackAction<_AddItemIntent>(
            onInvoke: (_) {
              _addItem();
              return null;
            },
          ),
        },
        child: FocusScope(
          child: Focus(
            focusNode: _focusNode,
            child: Scaffold(
            appBar: AppBar(
              title: Text('Hromadný príjem (${_items.length} položiek)'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _saveDraft,
                  tooltip: 'Uložiť rozpracovaný príjem',
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: () async {
                    final drafts = await _loadDrafts();
                    if (drafts.isEmpty) {
                      if (mounted) {
                        final mediaQuery = MediaQuery.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Žiadne rozpracované príjmy'),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            margin: EdgeInsets.only(
                              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                              left: 16,
                              right: 16,
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    
                    final selected = await showDialog<BulkReceiptDraft>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Rozpracované príjmy'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: drafts.length,
                            itemBuilder: (context, index) {
                              final draft = drafts[index];
                              // Calculate totals for preview
                              double totalWithVat = 0;
                              for (final item in draft.items) {
                                if (item.material != null && item.quantity > 0) {
                                  if (item.purchasePriceWithVat != null) {
                                    totalWithVat += item.purchasePriceWithVat! * item.quantity;
                                  } else if (item.purchasePriceWithoutVat != null) {
                                    totalWithVat += item.purchasePriceWithoutVat! * (1 + item.vatRate / 100) * item.quantity;
                                  }
                                }
                              }
                              
                              return ListTile(
                                title: Text(
                                  draft.name ?? 'Príjem z ${DateFormat('dd.MM.yyyy').format(draft.receiptDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${draft.items.length} položiek • '
                                      '${draft.supplierName ?? 'Bez dodávateľa'}',
                                    ),
                                    if (totalWithVat > 0)
                                      Text(
                                        'Celková hodnota: ${totalWithVat.toStringAsFixed(2)} €',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    Text(
                                      'Upravené: ${DateFormat('dd.MM.yyyy HH:mm').format(draft.updatedAt ?? draft.createdAt)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      'Upravené: ${DateFormat('dd.MM.yyyy HH:mm').format(draft.updatedAt ?? draft.createdAt)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () async {
                                        await _duplicateDraft(draft);
                                        Navigator.pop(context);
                                      },
                                      tooltip: 'Duplikovať',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        final prefs = await SharedPreferences.getInstance();
                                        final updatedDrafts = List<BulkReceiptDraft>.from(drafts);
                                        updatedDrafts.removeAt(index);
                                        final draftsJson = updatedDrafts.map((d) => jsonEncode(d.toJson())).toList();
                                        await prefs.setStringList('bulk_receipt_drafts', draftsJson);
                                        Navigator.pop(context);
                                        if (mounted) {
                                          final mediaQuery = MediaQuery.of(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Rozpracovaný príjem bol vymazaný'),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                                                left: 16,
                                                right: 16,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      tooltip: 'Vymazať',
                                    ),
                                  ],
                                ),
                                onTap: () => Navigator.pop(context, draft),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Zrušiť'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await showDialog<List<BulkReceiptDraft>>(
                                context: context,
                                builder: (context) => _MergeDraftsDialog(drafts: drafts),
                              );
                              if (result != null && result.isNotEmpty) {
                                await _mergeDrafts(result);
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Zlúčiť'),
                          ),
                        ],
                      ),
                    );
                    
                    if (selected != null) {
                      await _loadDraft(selected);
                    }
                  },
                  tooltip: 'Načítať rozpracovaný príjem',
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _showBatchScanDialog,
                  tooltip: 'Batch skenovanie QR kódov',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                  tooltip: 'Pridať položku (Ctrl + .)',
                ),
              ],
            ),
            body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Common info
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Spoločné informácie',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Dátum príjmu'),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(_receiptDate)),
                      trailing: const Icon(Icons.chevron_right),
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
                    const Divider(),
                    // Delivery date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_shipping),
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
                          const Icon(Icons.chevron_right),
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
                    const Divider(),
                    // Delivery note number
                    TextFormField(
                      controller: _deliveryNoteNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Číslo dodacieho listu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Zadajte číslo dodacieho listu',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Supplier
                    DropdownButtonFormField<Supplier>(
                      value: _selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Dodávateľ',
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
                            // Automaticky nastav DPH sadzbu podľa dodávateľa
                            if (supplier.defaultVatRate != null) {
                              _globalVatRate = supplier.defaultVatRate!;
                              // Aktualizuj všetky items
                              for (final item in _items) {
                                item.vatRate = _globalVatRate;
                                // Recalculate prices
                                if (item.purchasePriceWithoutVat != null && item.purchasePriceWithoutVat! > 0) {
                                  if (_globalVatRate == 0) {
                                    item.purchasePriceWithVat = item.purchasePriceWithoutVat;
                                  } else {
                                    item.purchasePriceWithVat = item.purchasePriceWithoutVat! * (1 + _globalVatRate / 100);
                                  }
                                } else if (item.purchasePriceWithVat != null && item.purchasePriceWithVat! > 0) {
                                  if (_globalVatRate == 0) {
                                    item.purchasePriceWithoutVat = item.purchasePriceWithVat;
                                  } else {
                                    item.purchasePriceWithoutVat = item.purchasePriceWithVat! / (1 + _globalVatRate / 100);
                                  }
                                }
                              }
                            }
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
                      ),
                      enabled: _selectedSupplier == null,
                    ),
                    // Zobrazenie kontaktných údajov dodávateľa
                    if (_selectedSupplier != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.contact_phone, size: 18, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Kontaktné údaje',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedSupplier!.phone != null)
                              Text('Tel: ${_selectedSupplier!.phone}', style: const TextStyle(fontSize: 12)),
                            if (_selectedSupplier!.email != null)
                              Text('Email: ${_selectedSupplier!.email}', style: const TextStyle(fontSize: 12)),
                            if (_selectedSupplier!.address != null)
                              Text('Adresa: ${_selectedSupplier!.address}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('História príjmov'),
                              onPressed: () => _showSupplierHistory(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            const SizedBox(height: 24),

            // Items header with global VAT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Položky (${_items.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.percent, size: 18),
                      const SizedBox(width: 4),
                      const Text('DPH pre všetky:'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: _globalVatRate.toStringAsFixed(0),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            if (value.contains(',')) {
                              final newValue = value.replaceAll(',', '.');
                              // Update the controller
                              final controller = TextEditingController(text: newValue);
                              controller.selection = TextSelection.collapsed(offset: newValue.length);
                            }
                            final vat = _parseNumber(value);
                            if (vat != null && vat != _globalVatRate) {
                              setState(() {
                                _globalVatRate = vat;
                                // Apply to all items and recalculate prices
                                for (int i = 0; i < _items.length; i++) {
                                  final item = _items[i];
                                  item.vatRate = vat;
                                  
                                  // Recalculate prices based on what's already set
                                  // Priority: if both are set, keep the one that was manually entered
                                  // If only one is set, recalculate the other
                                  
                                  // If purchase price without VAT is set, recalculate with VAT
                                  if (item.purchasePriceWithoutVat != null && item.purchasePriceWithoutVat! > 0) {
                                    if (vat == 0) {
                                      item.purchasePriceWithVat = item.purchasePriceWithoutVat;
                                    } else {
                                      item.purchasePriceWithVat = item.purchasePriceWithoutVat! * (1 + vat / 100);
                                    }
                                  }
                                  // If purchase price with VAT is set, recalculate without VAT
                                  else if (item.purchasePriceWithVat != null && item.purchasePriceWithVat! > 0) {
                                    if (vat == 0) {
                                      item.purchasePriceWithoutVat = item.purchasePriceWithVat;
                                    } else {
                                      item.purchasePriceWithoutVat = item.purchasePriceWithVat! / (1 + vat / 100);
                                    }
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const Text('%'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Summary card
            if (_items.any((item) => item.material != null && item.quantity > 0))
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Súhrn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Celková hodnota bez DPH:'),
                          Text(
                            '${_calculateTotalWithoutVat().toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DPH:'),
                          Text(
                            '${_calculateTotalVat().toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Celková hodnota s DPH:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            '${_calculateTotalWithVat().toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Priemerná cena na jednotku:'),
                          Text(
                            '${_calculateAveragePricePerUnit().toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.any((item) => item.material != null && item.quantity > 0))
              const SizedBox(height: 12),
            // Items list with reorderable
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              children: List.generate(_items.length, (index) {
                return _buildItemCard(index);
              }),
            ),
            const SizedBox(height: 24),

            // Preview and Save buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _showPreview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Náhľad'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveBulkReceipt,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Ukladanie...' : 'Zaznamenať hromadný príjem'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    // Initialize controllers with current values
    final quantityController = TextEditingController(
      text: item.quantity > 0 ? item.quantity.toString() : '',
    );
    final priceWithoutVatController = TextEditingController(
      text: _formatPrice(item.purchasePriceWithoutVat),
    );
    final priceWithVatController = TextEditingController(
      text: _formatPrice(item.purchasePriceWithVat),
    );
    final vatRateController = TextEditingController(
      text: item.vatRate.toStringAsFixed(0),
    );
    
    // Update controllers when global VAT changes
    vatRateController.text = item.vatRate.toStringAsFixed(0);
    if (item.purchasePriceWithoutVat != null && item.purchasePriceWithoutVat! > 0) {
      priceWithoutVatController.text = _formatPrice(item.purchasePriceWithoutVat);
      if (item.purchasePriceWithVat != null) {
        priceWithVatController.text = _formatPrice(item.purchasePriceWithVat);
      }
    } else if (item.purchasePriceWithVat != null && item.purchasePriceWithVat! > 0) {
      priceWithVatController.text = _formatPrice(item.purchasePriceWithVat);
      if (item.purchasePriceWithoutVat != null) {
        priceWithoutVatController.text = _formatPrice(item.purchasePriceWithoutVat);
      }
    }

    return Card(
      key: ValueKey('item_$index'),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Položka ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _removeItem(index),
                    tooltip: 'Odstrániť položku',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // PLU/EAN search row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('plu_ean_$index'),
                    decoration: InputDecoration(
                      labelText: 'PLU alebo EAN',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            onPressed: () => _scanQrCode(index),
                            tooltip: 'Skenovať QR kód',
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            onPressed: () => _searchByCode(index),
                            tooltip: 'Vyhľadať podľa kódu',
                          ),
                        ],
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onFieldSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _searchByCode(index, code: value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Autocomplete<material_model.Material>(
                    key: ValueKey('product_${index}_${item.material?.id ?? 'null'}'),
                    initialValue: item.material != null 
                        ? TextEditingValue(text: '${item.material!.name} (${item.material!.unit})${item.material!.pluCode != null ? ' [PLU: ${item.material!.pluCode}]' : ''}${item.material!.eanCode != null ? ' [EAN: ${item.material!.eanCode}]' : ''}')
                        : const TextEditingValue(),
                    displayStringForOption: (material) => '${material.name} (${material.unit})${material.pluCode != null ? ' [PLU: ${material.pluCode}]' : ''}${material.eanCode != null ? ' [EAN: ${material.eanCode}]' : ''}',
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return _materials;
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _materials.where((material) {
                        final nameMatch = material.name.toLowerCase().contains(query);
                        final pluMatch = material.pluCode?.toLowerCase().contains(query) ?? false;
                        final eanMatch = material.eanCode?.toLowerCase().contains(query) ?? false;
                        return nameMatch || pluMatch || eanMatch;
                      }).toList();
                    },
                    onSelected: (material) {
                      setState(() {
                        // Ensure we use the material instance from _materials
                        material_model.Material materialFromList;
                        if (material.id != null) {
                          final matching = _materials.where((m) => m.id == material.id);
                          materialFromList = matching.isEmpty ? material : matching.first;
                        } else {
                          materialFromList = material;
                        }
                        item.material = materialFromList;
                        // Ak už má produkt nastavené ceny, použij ich
                        if (materialFromList.averagePurchasePriceWithVat != null) {
                          item.purchasePriceWithVat = materialFromList.averagePurchasePriceWithVat;
                        }
                        if (materialFromList.averagePurchasePriceWithoutVat != null) {
                          item.purchasePriceWithoutVat = materialFromList.averagePurchasePriceWithoutVat;
                        }
                        if (materialFromList.vatRate != null) {
                          item.vatRate = materialFromList.vatRate!;
                        }
                        item.category = materialFromList.category;
                      });
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController textEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Nastav hodnotu v controllery, ak má item materiál
                      if (item.material != null && textEditingController.text.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (textEditingController.text.isEmpty) {
                            textEditingController.text = '${item.material!.name} (${item.material!.unit})${item.material!.pluCode != null ? ' [PLU: ${item.material!.pluCode}]' : ''}${item.material!.eanCode != null ? ' [EAN: ${item.material!.eanCode}]' : ''}';
                          }
                        });
                      }
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Názov produktu',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.text_fields, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            onPressed: () => _searchMaterial(index),
                            tooltip: 'Vyhľadať podľa názvu',
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onFieldSubmitted: (value) {
                          onFieldSubmitted();
                          if (value.trim().isNotEmpty) {
                            _searchByName(index, name: value.trim());
                          }
                        },
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<material_model.Material> onSelected,
                      Iterable<material_model.Material> options,
                    ) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: material_widget.Material(
                          type: MaterialType.card,
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final material = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(material.name),
                                  subtitle: Text(
                                    '${material.unit}${material.pluCode != null ? ' • PLU: ${material.pluCode}' : ''}${material.eanCode != null ? ' • EAN: ${material.eanCode}' : ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () {
                                    onSelected(material);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Main row: Material, Quantity, Category, Prices
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material search/select
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<material_model.Material>(
                          value: item.material != null && item.material!.id != null
                              ? _materials.where((m) => m.id == item.material!.id).isNotEmpty
                                  ? _materials.firstWhere((m) => m.id == item.material!.id)
                                  : null
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Materiál *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2, size: 20),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _materials.map((material) {
                            return DropdownMenuItem<material_model.Material>(
                              value: material,
                              child: Text(
                                '${material.name} (${material.unit})${material.pluCode != null ? ' [PLU: ${material.pluCode}]' : ''}${material.eanCode != null ? ' [EAN: ${material.eanCode}]' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (material) async {
                            setState(() {
                              item.material = material;
                            });
                            // Zobraziť poslednú nákupnú cenu
                            if (material != null && material.id != null) {
                              final lastPrice = await _getLastPurchasePrice(material.id!);
                              if (lastPrice != null && mounted) {
                                final mediaQuery = MediaQuery.of(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Posledná nákupná cena: ${lastPrice.purchasePriceWithoutVat.toStringAsFixed(2)} € bez DPH '
                                      '(${DateFormat('dd.MM.yyyy').format(DateTime.parse(lastPrice.priceDate))})',
                                    ),
                                    duration: const Duration(seconds: 3),
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
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Vyberte';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (item.material != null && item.material!.id != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.blue.shade700),
                          onPressed: () => _editMaterial(item.material!),
                          tooltip: 'Upraviť materiál',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                // Quantity
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText: 'Množstvo${item.material != null ? ' (${item.material!.unit})' : ''} *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.scale, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          if (value.contains(',')) {
                            final newValue = value.replaceAll(',', '.');
                            quantityController.value = TextEditingValue(
                              text: newValue,
                              selection: TextSelection.collapsed(offset: newValue.length),
                            );
                          }
                          item.quantity = _parseNumber(value) ?? 0;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Zadajte';
                          }
                          final parsed = _parseNumber(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Neplatné';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      // Quick quantity buttons
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _commonQuantities.map((qty) {
                          return ActionChip(
                            label: Text(qty.toStringAsFixed(0)),
                            onPressed: () {
                              setState(() {
                                item.quantity = qty;
                                quantityController.text = qty.toStringAsFixed(0);
                              });
                            },
                            backgroundColor: item.quantity == qty 
                                ? Colors.blue.shade100 
                                : Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: item.quantity == qty 
                                  ? Colors.blue.shade900 
                                  : Colors.black87,
                              fontSize: 11,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                // Category
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: item.category,
                    decoration: const InputDecoration(
                      labelText: 'Kategória',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'warehouse', child: Text('Sklad')),
                      DropdownMenuItem(value: 'production', child: Text('Výroba')),
                      DropdownMenuItem(value: 'retail', child: Text('Maloobchod')),
                      DropdownMenuItem(value: 'overhead', child: Text('Režijný materiál')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        item.category = value ?? 'warehouse';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Prices row
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        'Nákupné ceny (voliteľné)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // VAT Rate
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: vatRateController,
                          decoration: const InputDecoration(
                            labelText: 'DPH (%)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.percent, size: 18),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            if (value.contains(',')) {
                              final newValue = value.replaceAll(',', '.');
                              vatRateController.value = TextEditingValue(
                                text: newValue,
                                selection: TextSelection.collapsed(offset: newValue.length),
                              );
                            }
                            item.vatRate = _parseNumber(value) ?? 0.0;
                            _calculatePriceWithVat(index);
                            if (item.purchasePriceWithoutVat != null) {
                              priceWithVatController.text = item.purchasePriceWithVat?.toStringAsFixed(2) ?? '';
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Purchase price without VAT
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: priceWithoutVatController,
                          decoration: InputDecoration(
                            labelText: 'Nákupná cena bez DPH (€)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.shopping_cart, size: 18),
                            suffixText: item.material != null ? 'za ${item.material!.unit}' : null,
                            helperText: 'Cena pri nákupe',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            if (value.contains(',')) {
                              final newValue = value.replaceAll(',', '.');
                              priceWithoutVatController.value = TextEditingValue(
                                text: newValue,
                                selection: TextSelection.collapsed(offset: newValue.length),
                              );
                            }
                            item.purchasePriceWithoutVat = _parseNumber(value);
                            _calculatePriceWithVat(index);
                            if (item.purchasePriceWithoutVat != null) {
                              priceWithVatController.text = _formatPrice(item.purchasePriceWithVat);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Purchase price with VAT
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: priceWithVatController,
                          decoration: InputDecoration(
                            labelText: 'Nákupná cena s DPH (€)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.shopping_bag, size: 18),
                            suffixText: item.material != null ? 'za ${item.material!.unit}' : null,
                            helperText: 'Cena pri nákupe',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            if (value.contains(',')) {
                              final newValue = value.replaceAll(',', '.');
                              priceWithVatController.value = TextEditingValue(
                                text: newValue,
                                selection: TextSelection.collapsed(offset: newValue.length),
                              );
                            }
                            item.purchasePriceWithVat = _parseNumber(value);
                            _calculatePriceWithoutVat(index);
                            if (item.purchasePriceWithVat != null) {
                              priceWithoutVatController.text = _formatPrice(item.purchasePriceWithoutVat);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  // QR Code scanning
  Future<void> _scanQrCode(int itemIndex) async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (context) => _QrScanDialog(),
    );
    
    if (scannedCode != null && scannedCode.isNotEmpty) {
      await _searchByCode(itemIndex, code: scannedCode);
    }
  }

  // Batch QR scanning
  Future<void> _showBatchScanDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _BatchScanDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      for (final code in result) {
        // Find existing item with this code or create new
        bool found = false;
        for (final item in _items) {
          if (item.material?.pluCode == code || item.material?.eanCode == code) {
            // Update quantity
            setState(() {
              item.quantity += 1;
            });
            found = true;
            break;
          }
        }
        
        if (!found) {
          // Create new item
          final newItem = BulkReceiptItem()..vatRate = _globalVatRate;
          _items.add(newItem);
          await _searchByCode(_items.length - 1, code: code);
        }
      }
    }
  }

  // Duplicate draft
  Future<void> _duplicateDraft(BulkReceiptDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await _loadDrafts();
    
    final duplicatedDraft = BulkReceiptDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${draft.name ?? 'Príjem'} (kópia)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      selectedSupplier: draft.selectedSupplier,
      supplierName: draft.supplierName,
      deliveryNoteNumber: draft.deliveryNoteNumber,
      receiptDate: draft.receiptDate,
      deliveryDate: draft.deliveryDate,
      globalVatRate: draft.globalVatRate,
      items: draft.items.map((item) {
        final newItem = BulkReceiptItem()
          ..material = item.material
          ..quantity = item.quantity
          ..purchasePriceWithoutVat = item.purchasePriceWithoutVat
          ..purchasePriceWithVat = item.purchasePriceWithVat
          ..vatRate = item.vatRate
          ..category = item.category
          ..documentNumber = item.documentNumber
          ..location = item.location
          ..notes = item.notes;
        return newItem;
      }).toList(),
    );
    
    drafts.insert(0, duplicatedDraft);
    final draftsJson = drafts.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList('bulk_receipt_drafts', draftsJson);
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Draft bol duplikovaný'),
          backgroundColor: Colors.green,
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

  // Merge drafts
  Future<void> _mergeDrafts(List<BulkReceiptDraft> draftsToMerge) async {
    if (draftsToMerge.isEmpty) return;
    
    final allItems = <BulkReceiptItem>[];
    DateTime latestDate = draftsToMerge.first.receiptDate;
    Supplier? mergedSupplier = draftsToMerge.first.selectedSupplier;
    String? mergedSupplierName = draftsToMerge.first.supplierName;
    double mergedVatRate = draftsToMerge.first.globalVatRate;
    
    for (final draft in draftsToMerge) {
      allItems.addAll(draft.items);
      if (draft.receiptDate.isAfter(latestDate)) {
        latestDate = draft.receiptDate;
      }
      if (draft.selectedSupplier != null) {
        mergedSupplier = draft.selectedSupplier;
        mergedSupplierName = draft.supplierName;
      }
      if (draft.globalVatRate != 20.0) {
        mergedVatRate = draft.globalVatRate;
      }
    }
    
    // Load merged draft
    final mergedDraft = BulkReceiptDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Zlúčený príjem (${draftsToMerge.length} draftov)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      selectedSupplier: mergedSupplier,
      supplierName: mergedSupplierName,
      deliveryNoteNumber: null,
      receiptDate: latestDate,
      deliveryDate: null,
      globalVatRate: mergedVatRate,
      items: allItems,
    );
    
    await _loadDraft(mergedDraft);
    
    // Delete merged drafts
    final prefs = await SharedPreferences.getInstance();
    final allDrafts = await _loadDrafts();
    final mergedIds = draftsToMerge.map((d) => d.id).toSet();
    allDrafts.removeWhere((d) => mergedIds.contains(d.id));
    final draftsJson = allDrafts.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList('bulk_receipt_drafts', draftsJson);
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${draftsToMerge.length} draftov bolo zlúčených'),
          backgroundColor: Colors.green,
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

  // Show preview
  Future<void> _showPreview() async {
    final validItems = _items.where((item) => 
      item.material != null && item.quantity > 0
    ).toList();

    if (validItems.isEmpty) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pridajte aspoň jednu položku pre náhľad'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ReceiptPreviewDialog(
        items: validItems,
        supplier: _selectedSupplier,
        supplierName: _supplierController.text.isEmpty ? null : _supplierController.text,
        receiptDate: _receiptDate,
        deliveryDate: _deliveryDate,
        deliveryNoteNumber: _deliveryNoteNumberController.text.isEmpty 
            ? null 
            : _deliveryNoteNumberController.text,
        totalWithoutVat: _calculateTotalWithoutVat(),
        totalWithVat: _calculateTotalWithVat(),
        totalVat: _calculateTotalVat(),
        averagePrice: _calculateAveragePricePerUnit(),
      ),
    );
  }

  // Supplier history
  Future<void> _showSupplierHistory() async {
    if (_selectedSupplier == null || _selectedSupplier!.id == null) return;
    
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final supplierMovements = await dbProvider.getStockMovements(
      supplierId: _selectedSupplier!.id,
      movementType: 'receipt',
      status: 'approved',
    );
    supplierMovements.sort((a, b) => b.movementDate.compareTo(a.movementDate));
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('História príjmov - ${_selectedSupplier!.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: supplierMovements.isEmpty
              ? const Text('Žiadne príjmy od tohto dodávateľa')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: supplierMovements.length > 10 ? 10 : supplierMovements.length,
                  itemBuilder: (context, index) {
                    final movement = supplierMovements[index];
                    final totalValue = (movement.purchasePriceWithVat ?? movement.purchasePriceWithoutVat ?? 0.0) * movement.quantity;
                    return ListTile(
                      title: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(movement.movementDate))),
                      subtitle: Text(
                        '${movement.quantity} ${movement.unit} • ${totalValue.toStringAsFixed(2)} €',
                      ),
                      trailing: movement.receiptNumber != null
                          ? Text(movement.receiptNumber!, style: const TextStyle(fontSize: 12))
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchByCode(int itemIndex, {String? code}) async {
    final item = _items[itemIndex];
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    if (code == null || code.isEmpty) {
      // Zobraz dialog na zadanie kódu
      final codeController = TextEditingController();
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vyhľadať podľa PLU alebo EAN'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'PLU alebo EAN kód',
              hintText: 'Zadajte PLU alebo EAN kód',
              prefixIcon: Icon(Icons.qr_code),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, true);
                _searchByCode(itemIndex, code: value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                  _searchByCode(itemIndex, code: codeController.text.trim());
                }
              },
              child: const Text('Vyhľadať'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Vyhľadaj podľa kódu
    final foundMaterial = await dbProvider.findMaterialByCode(code);
    
    if (foundMaterial != null && foundMaterial.id != null) {
      // Produkt sa našiel - zabezpeč, že je v zozname _materials (bez duplikátov)
      final existingIndex = _materials.indexWhere((m) => m.id == foundMaterial.id);
      if (existingIndex >= 0) {
        // Aktualizuj existujúci materiál
        setState(() {
          _materials[existingIndex] = foundMaterial;
          item.material = foundMaterial;
        });
      } else {
        // Pridaj nový materiál
        setState(() {
          _materials.add(foundMaterial);
          item.material = foundMaterial;
          // Ak už má produkt nastavené ceny, použij ich
          if (foundMaterial.averagePurchasePriceWithVat != null) {
            item.purchasePriceWithVat = foundMaterial.averagePurchasePriceWithVat;
          }
          if (foundMaterial.averagePurchasePriceWithoutVat != null) {
            item.purchasePriceWithoutVat = foundMaterial.averagePurchasePriceWithoutVat;
          }
          if (foundMaterial.vatRate != null) {
            item.vatRate = foundMaterial.vatRate!;
          }
          // Nastav kategóriu z produktu
          item.category = foundMaterial.category;
        });
      }
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produkt "${foundMaterial.name}" bol nájdený a vybraný'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    } else {
      // Produkt sa nenašiel - ponúkni vytvorenie
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Produkt sa nenašiel'),
          content: Text('Produkt s kódom "$code" sa nenašiel. Chcete vytvoriť nový produkt?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vytvoriť'),
            ),
          ],
        ),
      );
      
      if (shouldCreate == true) {
        await _createNewMaterial(itemIndex, '', pluOrEan: code);
      }
    }
  }

  Future<void> _searchByName(int itemIndex, {String? name}) async {
    final item = _items[itemIndex];
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    if (name == null || name.isEmpty) {
      _searchMaterial(itemIndex);
      return;
    }
    
    // Vyhľadaj podľa názvu
    final foundMaterials = await dbProvider.searchMaterialsByName(name);
    
    if (foundMaterials.isNotEmpty) {
      if (foundMaterials.length == 1) {
        // Našiel sa presne jeden produkt - zabezpeč, že je v zozname _materials (bez duplikátov)
        final found = foundMaterials.first;
        if (found.id != null) {
          final existingIndex = _materials.indexWhere((m) => m.id == found.id);
          if (existingIndex >= 0) {
            setState(() {
              _materials[existingIndex] = found;
              item.material = found;
            });
          } else {
            setState(() {
              _materials.add(found);
              item.material = found;
            });
          }
        } else {
          setState(() {
            item.material = found;
            if (found.averagePurchasePriceWithVat != null) {
              item.purchasePriceWithVat = found.averagePurchasePriceWithVat;
            }
            if (found.averagePurchasePriceWithoutVat != null) {
              item.purchasePriceWithoutVat = found.averagePurchasePriceWithoutVat;
            }
            if (found.vatRate != null) {
              item.vatRate = found.vatRate!;
            }
            item.category = found.category;
          });
        }
        
        // Aktualizuj ceny aj pre existujúci materiál
        if (found.id != null) {
          final existingIndex = _materials.indexWhere((m) => m.id == found.id);
          if (existingIndex >= 0) {
            setState(() {
              if (found.averagePurchasePriceWithVat != null) {
                item.purchasePriceWithVat = found.averagePurchasePriceWithVat;
              }
              if (found.averagePurchasePriceWithoutVat != null) {
                item.purchasePriceWithoutVat = found.averagePurchasePriceWithoutVat;
              }
              if (found.vatRate != null) {
                item.vatRate = found.vatRate!;
              }
              item.category = found.category;
            });
          }
        }
        
        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produkt "${foundMaterials.first.name}" bol nájdený a vybraný'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                left: 16,
                right: 16,
              ),
            ),
          );
        }
      } else {
        // Našlo sa viac produktov - zobraz výber
        final selected = await showDialog<material_model.Material>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vyberte produkt'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: foundMaterials.length,
                itemBuilder: (context, idx) {
                  final material = foundMaterials[idx];
                  return ListTile(
                    title: Text(material.name),
                    subtitle: Text(
                      '${material.unit}${material.pluCode != null ? ' • PLU: ${material.pluCode}' : ''}${material.eanCode != null ? ' • EAN: ${material.eanCode}' : ''}',
                    ),
                    onTap: () => Navigator.pop(context, material),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrušiť'),
              ),
            ],
          ),
        );
        
        if (selected != null && selected.id != null) {
          // Zabezpeč, že vybraný materiál je v zozname _materials (bez duplikátov)
          final existingIndex = _materials.indexWhere((m) => m.id == selected.id);
          if (existingIndex >= 0) {
            setState(() {
              _materials[existingIndex] = selected;
              item.material = selected;
            });
          } else {
            setState(() {
              _materials.add(selected);
              item.material = selected;
            });
          }
          
          setState(() {
            if (selected.averagePurchasePriceWithVat != null) {
              item.purchasePriceWithVat = selected.averagePurchasePriceWithVat;
            }
            if (selected.averagePurchasePriceWithoutVat != null) {
              item.purchasePriceWithoutVat = selected.averagePurchasePriceWithoutVat;
            }
            if (selected.vatRate != null) {
              item.vatRate = selected.vatRate!;
            }
            item.category = selected.category;
          });
        }
      }
    } else {
      // Produkt sa nenašiel
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Produkt sa nenašiel'),
          content: Text('Produkt s názvom "$name" sa nenašiel. Chcete vytvoriť nový produkt?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vytvoriť'),
            ),
          ],
        ),
      );
      
      if (shouldCreate == true) {
        await _createNewMaterial(itemIndex, name);
      }
    }
  }

  Future<void> _searchMaterial(int itemIndex) async {
    final item = _items[itemIndex];
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final searchController = TextEditingController();
    material_model.Material? foundMaterial;
    
    final result = await showDialog<material_model.Material>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vyhľadať produkt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Názov, PLU alebo EAN',
                  hintText: 'Zadajte názov produktu, PLU alebo EAN kód',
                  prefixIcon: Icon(Icons.search),
                ),
                autofocus: true,
                onSubmitted: (value) async {
                  if (value.trim().isEmpty) {
                    setDialogState(() {
                      foundMaterial = null;
                    });
                    return;
                  }
                  
                  // Najprv skús nájsť podľa PLU/EAN
                  final byCode = await dbProvider.findMaterialByCode(value.trim());
                  if (byCode != null) {
                    setDialogState(() {
                      foundMaterial = byCode;
                    });
                    return;
                  }
                  
                  // Ak sa nenašlo podľa kódu, skús podľa názvu
                  final byName = await dbProvider.searchMaterialsByName(value.trim());
                  if (byName.isNotEmpty) {
                    setDialogState(() {
                      foundMaterial = byName.first;
                    });
                  } else {
                    setDialogState(() {
                      foundMaterial = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (foundMaterial != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nájdený produkt:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Názov: ${foundMaterial!.name}'),
                      Text('Jednotka: ${foundMaterial!.unit}'),
                      if (foundMaterial!.pluCode != null)
                        Text('PLU: ${foundMaterial!.pluCode}'),
                      if (foundMaterial!.eanCode != null)
                        Text('EAN: ${foundMaterial!.eanCode}'),
                    ],
                  ),
                ),
              ] else if (searchController.text.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produkt sa nenašiel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Môžete vytvoriť nový produkt.'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            if (foundMaterial != null)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, foundMaterial),
                child: const Text('Použiť'),
              )
            else if (searchController.text.trim().isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _createNewMaterial(itemIndex, searchController.text.trim());
                },
                icon: const Icon(Icons.add),
                label: const Text('Vytvoriť nový'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
    
    if (result != null && result.id != null) {
      // Zabezpeč, že nájdený materiál je v zozname _materials (bez duplikátov)
      final existingIndex = _materials.indexWhere((m) => m.id == result.id);
      if (existingIndex >= 0) {
        setState(() {
          _materials[existingIndex] = result;
          item.material = result;
        });
      } else {
        setState(() {
          _materials.add(result);
          item.material = result;
        });
      }
      
      setState(() {
        // Ak už má produkt nastavené ceny, použij ich
        if (result.averagePurchasePriceWithVat != null) {
          item.purchasePriceWithVat = result.averagePurchasePriceWithVat;
        }
        if (result.averagePurchasePriceWithoutVat != null) {
          item.purchasePriceWithoutVat = result.averagePurchasePriceWithoutVat;
        }
        if (result.vatRate != null) {
          item.vatRate = result.vatRate!;
        }
        // Nastav kategóriu z produktu
        item.category = result.category;
      });
    }
  }

  Future<void> _createNewMaterial(int itemIndex, String searchText, {String? pluOrEan}) async {
    final item = _items[itemIndex];
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    // Otvorí dialog na vytvorenie nového materiálu
    final newMaterial = await showDialog<material_model.Material>(
      context: context,
      builder: (context) => _CreateMaterialDialog(
        initialName: searchText,
        initialCategory: item.category,
        initialVatRate: item.vatRate,
        initialPriceWithoutVat: item.purchasePriceWithoutVat,
        initialPriceWithVat: item.purchasePriceWithVat,
        selectedSupplier: _selectedSupplier,
        initialPluOrEan: pluOrEan,
      ),
    );
    
    if (newMaterial != null) {
      // Ulož nový materiál
      final materialId = await dbProvider.insertMaterial(newMaterial);
      final savedMaterial = newMaterial.copyWith(id: materialId);
      
      // Aktualizuj zoznam materiálov (bez duplikátov)
      setState(() {
        if (!_materials.any((m) => m.id == savedMaterial.id)) {
          _materials.add(savedMaterial);
        }
        item.material = savedMaterial;
        // Nastav ceny z nového materiálu
        if (savedMaterial.averagePurchasePriceWithVat != null) {
          item.purchasePriceWithVat = savedMaterial.averagePurchasePriceWithVat;
        }
        if (savedMaterial.averagePurchasePriceWithoutVat != null) {
          item.purchasePriceWithoutVat = savedMaterial.averagePurchasePriceWithoutVat;
        }
        if (savedMaterial.vatRate != null) {
          item.vatRate = savedMaterial.vatRate!;
        }
        item.category = savedMaterial.category;
      });
    }
  }
}

class _CreateMaterialDialog extends StatefulWidget {
  final String initialName;
  final String initialCategory;
  final double initialVatRate;
  final double? initialPriceWithoutVat;
  final double? initialPriceWithVat;
  final Supplier? selectedSupplier;
  final String? initialPluOrEan;

  const _CreateMaterialDialog({
    required this.initialName,
    required this.initialCategory,
    required this.initialVatRate,
    this.initialPriceWithoutVat,
    this.initialPriceWithVat,
    this.selectedSupplier,
    this.initialPluOrEan,
  });

  @override
  State<_CreateMaterialDialog> createState() => _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends State<_CreateMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pluController = TextEditingController();
  final _eanController = TextEditingController();
  final _warehouseNumberController = TextEditingController();
  String _selectedUnit = 'ks';
  final _minStockController = TextEditingController(text: '0');
  final _purchasePriceWithoutVatController = TextEditingController();
  final _purchasePriceWithVatController = TextEditingController();
  final _salePriceWithoutVatController = TextEditingController();
  final _salePriceWithVatController = TextEditingController();
  final _vatRateController = TextEditingController();
  final _recyclingFeeController = TextEditingController();
  
  String _selectedCategory = 'warehouse';
  String _selectedType = 'material';
  bool _hasRecyclingFee = false;
  
  final List<String> _units = ['kg', 't', 'm³', 'l', 'ks', 'm', 'm²'];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedCategory = widget.initialCategory;
    _vatRateController.text = widget.initialVatRate.toStringAsFixed(0);
    
    // Generuj automatické poradové číslo
    _generateWarehouseNumber();
    
    // Ak bol zadaný PLU/EAN, skús zistiť, či je to PLU alebo EAN (EAN je zvyčajne 13 číslic)
    if (widget.initialPluOrEan != null && widget.initialPluOrEan!.isNotEmpty) {
      if (widget.initialPluOrEan!.length >= 8 && RegExp(r'^\d+$').hasMatch(widget.initialPluOrEan!)) {
        // Pravdepodobne EAN (8-13 číslic)
        _eanController.text = widget.initialPluOrEan!;
      } else {
        // Pravdepodobne PLU
        _pluController.text = widget.initialPluOrEan!;
      }
    }
    
    if (widget.initialPriceWithoutVat != null) {
      _purchasePriceWithoutVatController.text = _formatPrice(widget.initialPriceWithoutVat);
    }
    if (widget.initialPriceWithVat != null) {
      _purchasePriceWithVatController.text = _formatPrice(widget.initialPriceWithVat);
    }
  }

  Future<void> _generateWarehouseNumber() async {
    final warehouseNumberService = WarehouseNumberService();
    final warehouseNumber = await warehouseNumberService.generateWarehouseNumber();
    setState(() {
      _warehouseNumberController.text = warehouseNumber;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pluController.dispose();
    _eanController.dispose();
    _warehouseNumberController.dispose();
    _minStockController.dispose();
    _purchasePriceWithoutVatController.dispose();
    _purchasePriceWithVatController.dispose();
    _salePriceWithoutVatController.dispose();
    _salePriceWithVatController.dispose();
    _vatRateController.dispose();
    _recyclingFeeController.dispose();
    super.dispose();
  }

  void _calculatePurchasePriceWithVat() {
    final priceWithoutVat = _parseNumber(_purchasePriceWithoutVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    
    if (priceWithoutVat != null && priceWithoutVat > 0) {
      final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
      _purchasePriceWithVatController.text = _formatPrice(priceWithVat);
    }
  }

  void _calculatePurchasePriceWithoutVat() {
    final priceWithVat = _parseNumber(_purchasePriceWithVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    
    if (priceWithVat != null && priceWithVat > 0) {
      if (vatRate == 0) {
        _purchasePriceWithoutVatController.text = _formatPrice(priceWithVat);
      } else {
        final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
        _purchasePriceWithoutVatController.text = _formatPrice(priceWithoutVat);
      }
    }
  }

  // Helper function to parse number with comma support
  double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
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

  // Helper function to format sale price with 2 decimal places
  String _formatSalePrice(double? price) {
    if (price == null) return '';
    if (price == 0) return '0.00';
    return price.toStringAsFixed(2);
  }

  // Legacy method for backward compatibility - uses purchase price formatting
  String _formatPrice(double? price) {
    return _formatPurchasePrice(price);
  }

  void _calculateSalePriceWithVat() {
    final priceWithoutVat = _parseNumber(_salePriceWithoutVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    
    if (priceWithoutVat != null && priceWithoutVat > 0) {
      final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
      _salePriceWithVatController.text = _formatSalePrice(priceWithVat);
    }
  }

  void _calculateSalePriceWithoutVat() {
    final priceWithVat = _parseNumber(_salePriceWithVatController.text);
    final vatRate = _parseNumber(_vatRateController.text) ?? 0.0;
    
    if (priceWithVat != null && priceWithVat > 0) {
      if (vatRate == 0) {
        _salePriceWithoutVatController.text = _formatSalePrice(priceWithVat);
      } else {
        final priceWithoutVat = priceWithVat / (1 + vatRate / 100);
        _salePriceWithoutVatController.text = _formatSalePrice(priceWithoutVat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Vytvoriť nový produkt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // Základné informácie
              const Text(
                'Základné informácie',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Názov produktu *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadajte názov';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pluController,
                      decoration: const InputDecoration(
                        labelText: 'PLU kód',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _eanController,
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategória *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'warehouse', child: Text('Sklad')),
                        DropdownMenuItem(value: 'production', child: Text('Výroba')),
                          DropdownMenuItem(value: 'retail', child: Text('Maloobchod')),
                        DropdownMenuItem(value: 'overhead', child: Text('Režijný materiál')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? 'warehouse';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Jednotka *',
                        border: OutlineInputBorder(),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value ?? 'ks';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vyberte jednotku';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minStockController,
                decoration: const InputDecoration(
                  labelText: 'Minimálny stav',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _warehouseNumberController,
                decoration: const InputDecoration(
                  labelText: 'Poradové číslo na sklade',
                  hintText: 'Automaticky generované',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                readOnly: false, // Umožníme úpravu, ak používateľ chce
              ),
              const SizedBox(height: 24),
              
              // DPH sadzba
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.percent, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Sadzba DPH',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _vatRateController,
                      decoration: InputDecoration(
                        labelText: 'DPH (%)',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        if (value.contains(',')) {
                          final newValue = value.replaceAll(',', '.');
                          _vatRateController.value = TextEditingValue(
                            text: newValue,
                            selection: TextSelection.collapsed(offset: newValue.length),
                          );
                        }
                        _calculatePurchasePriceWithVat();
                        _calculateSalePriceWithVat();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Nákupné ceny
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Nákupné ceny',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceWithoutVatController,
                            decoration: InputDecoration(
                              labelText: 'Bez DPH (€)',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.green.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.euro, size: 18),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              if (value.contains(',')) {
                                final newValue = value.replaceAll(',', '.');
                                _purchasePriceWithoutVatController.value = TextEditingValue(
                                  text: newValue,
                                  selection: TextSelection.collapsed(offset: newValue.length),
                                );
                              }
                              _calculatePurchasePriceWithVat();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceWithVatController,
                            decoration: InputDecoration(
                              labelText: 'S DPH (€)',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.green.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.euro, size: 18),
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
                              _calculatePurchasePriceWithoutVat();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Predajné ceny
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sell, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Predajné ceny',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceWithoutVatController,
                            decoration: InputDecoration(
                              labelText: 'Bez DPH (€)',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.orange.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.euro, size: 18),
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceWithVatController,
                            decoration: InputDecoration(
                              labelText: 'S DPH (€)',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.orange.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.euro, size: 18),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              if (value.contains(',')) {
                                final newValue = value.replaceAll(',', '.');
                                _salePriceWithVatController.value = TextEditingValue(
                                  text: newValue,
                                  selection: TextSelection.collapsed(offset: newValue.length),
                                );
                              }
                              _calculateSalePriceWithoutVat();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Recyklačný poplatok
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
                    Row(
                      children: [
                        Icon(Icons.recycling, color: Colors.teal.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Recyklačný poplatok',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                      dense: true,
                    ),
                    if (_hasRecyclingFee) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _recyclingFeeController,
                        decoration: InputDecoration(
                          labelText: 'Suma recyklačného poplatku (€)',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.euro, size: 18),
                          helperText: 'Zadajte sumu recyklačného poplatku',
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
                    ],
                  ),
                ),
              ),
            ),
            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Zrušiť'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        String? warehouseNumber = _warehouseNumberController.text.trim().isEmpty 
                            ? null 
                            : _warehouseNumberController.text.trim();
                        
                        // Ak nie je zadané poradové číslo, generuj ho automaticky
                        if (warehouseNumber == null || warehouseNumber.isEmpty) {
                          final warehouseNumberService = WarehouseNumberService();
                          warehouseNumber = await warehouseNumberService.generateWarehouseNumber();
                        }
                        
                        final material = material_model.Material(
                          name: _nameController.text.trim(),
                          type: _selectedType,
                          unit: _selectedUnit,
                          minStock: _parseNumber(_minStockController.text) ?? 0.0,
                          currentStock: 0.0,
                          pluCode: _pluController.text.trim().isEmpty ? null : _pluController.text.trim(),
                          eanCode: _eanController.text.trim().isEmpty ? null : _eanController.text.trim(),
                          category: _selectedCategory,
                          averagePurchasePriceWithoutVat: _parseNumber(_purchasePriceWithoutVatController.text),
                          averagePurchasePriceWithVat: _parseNumber(_purchasePriceWithVatController.text),
                          salePrice: _parseNumber(_salePriceWithVatController.text),
                          vatRate: _parseNumber(_vatRateController.text),
                          hasRecyclingFee: _hasRecyclingFee,
                          recyclingFee: _hasRecyclingFee && _recyclingFeeController.text.trim().isNotEmpty
                              ? _parseNumber(_recyclingFeeController.text)
                              : null,
                          defaultSupplierId: widget.selectedSupplier?.id,
                          warehouseNumber: warehouseNumber,
                          createdAt: DateTime.now().toIso8601String(),
                          updatedAt: DateTime.now().toIso8601String(),
                        );
                        
                        Navigator.pop(context, material);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Vytvoriť'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Merge Drafts Dialog
class _MergeDraftsDialog extends StatefulWidget {
  final List<BulkReceiptDraft> drafts;

  const _MergeDraftsDialog({required this.drafts});

  @override
  State<_MergeDraftsDialog> createState() => _MergeDraftsDialogState();
}

class _MergeDraftsDialogState extends State<_MergeDraftsDialog> {
  final Set<String> _selectedDraftIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zlúčiť drafty'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vyberte drafty na zlúčenie:'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.drafts.length,
                itemBuilder: (context, index) {
                  final draft = widget.drafts[index];
                  return CheckboxListTile(
                    title: Text(draft.name ?? 'Príjem z ${DateFormat('dd.MM.yyyy').format(draft.receiptDate)}'),
                    subtitle: Text('${draft.items.length} položiek'),
                    value: _selectedDraftIds.contains(draft.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedDraftIds.add(draft.id);
                        } else {
                          _selectedDraftIds.remove(draft.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: _selectedDraftIds.length < 2
              ? null
              : () {
                  final selectedDrafts = widget.drafts
                      .where((d) => _selectedDraftIds.contains(d.id))
                      .toList();
                  Navigator.pop(context, selectedDrafts);
                },
          child: const Text('Zlúčiť'),
        ),
      ],
    );
  }
}

// Receipt Preview Dialog
class _ReceiptPreviewDialog extends StatelessWidget {
  final List<BulkReceiptItem> items;
  final Supplier? supplier;
  final String? supplierName;
  final DateTime receiptDate;
  final DateTime? deliveryDate;
  final String? deliveryNoteNumber;
  final double totalWithoutVat;
  final double totalWithVat;
  final double totalVat;
  final double averagePrice;

  const _ReceiptPreviewDialog({
    required this.items,
    this.supplier,
    this.supplierName,
    required this.receiptDate,
    this.deliveryDate,
    this.deliveryNoteNumber,
    required this.totalWithoutVat,
    required this.totalWithVat,
    required this.totalVat,
    required this.averagePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.preview, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Náhľad príjmu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier info
                    if (supplier != null || supplierName != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dodávateľ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(supplier?.name ?? supplierName ?? ''),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dátum príjmu',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('dd.MM.yyyy').format(receiptDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (deliveryDate != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dátum dodania',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('dd.MM.yyyy').format(deliveryDate!)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (deliveryNoteNumber != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Číslo dodacieho listu',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(deliveryNoteNumber!),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Items
                    const Text(
                      'Položky',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final itemTotal = (item.purchasePriceWithVat ?? 
                          (item.purchasePriceWithoutVat != null 
                              ? item.purchasePriceWithoutVat! * (1 + item.vatRate / 100)
                              : 0.0)) * item.quantity;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item.material?.name ?? 'Neznámy materiál'),
                          subtitle: Text(
                            '${item.quantity} ${item.material?.unit ?? ''} × '
                            '${item.purchasePriceWithoutVat?.toStringAsFixed(2) ?? '0.00'} € '
                            '(${item.vatRate.toStringAsFixed(0)}% DPH)',
                          ),
                          trailing: Text(
                            '${itemTotal.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Totals
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildTotalRow('Celková hodnota bez DPH:', totalWithoutVat),
                            _buildTotalRow('DPH:', totalVat),
                            const Divider(),
                            _buildTotalRow(
                              'Celková hodnota s DPH:',
                              totalWithVat,
                              isBold: true,
                            ),
                            const SizedBox(height: 8),
                            _buildTotalRow('Priemerná cena na jednotku:', averagePrice),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Zavrieť'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} €',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

// QR Scan Dialog
class _QrScanDialog extends StatefulWidget {
  const _QrScanDialog();

  @override
  State<_QrScanDialog> createState() => _QrScanDialogState();
}

class _QrScanDialogState extends State<_QrScanDialog> {
  final codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Skenovať QR kód'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Zadajte alebo skenujte QR kód',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const QrCodeScreen(),
                ),
              );
              if (result != null && mounted) {
                Navigator.pop(context, result);
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Otvoriť QR scanner'),
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
            if (codeController.text.isNotEmpty) {
              Navigator.pop(context, codeController.text);
            }
          },
          child: const Text('Použiť'),
        ),
      ],
    );
  }
}

// Batch Scan Dialog
class _BatchScanDialog extends StatefulWidget {
  const _BatchScanDialog();

  @override
  State<_BatchScanDialog> createState() => _BatchScanDialogState();
}

class _BatchScanDialogState extends State<_BatchScanDialog> {
  final List<String> _scannedCodes = [];
  final _codeController = TextEditingController();

  Future<void> _scanCode() async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (context) => _QrScanDialog(),
    );
    
    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        if (!_scannedCodes.contains(scannedCode)) {
          _scannedCodes.add(scannedCode);
        }
      });
      _codeController.clear();
    }
  }

  void _addManualCode() {
    if (_codeController.text.trim().isNotEmpty) {
      setState(() {
        if (!_scannedCodes.contains(_codeController.text.trim())) {
          _scannedCodes.add(_codeController.text.trim());
        }
      });
      _codeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Batch skenovanie QR kódov'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Zadajte kód',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    onSubmitted: (_) => _addManualCode(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addManualCode,
                  tooltip: 'Pridať kód',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _scanCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Skenovať QR kód'),
            ),
            const SizedBox(height: 16),
            if (_scannedCodes.isEmpty)
              const Text('Žiadne naskenované kódy')
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _scannedCodes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: Text(_scannedCodes[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _scannedCodes.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _scannedCodes),
          child: const Text('Použiť'),
        ),
      ],
    );
  }
}


