import 'dart:typed_data';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/database_provider.dart';
import '../../providers/sync_provider.dart';
import '../../models/material.dart';
import '../../models/stock_movement.dart';
import '../../models/warehouse.dart';
import '../reports/export_service.dart';
import 'pallet_receive_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../qr_code/qr_code_screen.dart';
import 'bulk_receipt_screen.dart';
import 'receipts_pending_screen.dart';
import 'receipt_print_screen.dart';
import 'issue_screen.dart';
import 'inventory_screen.dart';
import 'movements_history_screen.dart';
import 'create_material_screen.dart';
import 'suppliers_screen.dart';
import 'customers_screen.dart';
import 'auto_orders_screen.dart';
import 'warehouse_closings_screen.dart';
import 'price_history_screen.dart';
import 'warehouses_screen.dart';
import 'warehouse_nav_notification.dart';
import '../home_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _SortConfig {
  final String column;
  final bool ascending;

  _SortConfig({required this.column, required this.ascending});
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ReceiptsPendingScreenState> _pendingKey = GlobalKey<ReceiptsPendingScreenState>();
  List<Material> _materials = [];
  List<Material> _filteredMaterials = [];
  List<Material> _lowStockMaterials = [];
  Map<int, StockMovement?> _lastPurchaseMovements = {}; // Cache for last purchase movements
  String? _selectedCategoryFilter; // null = všetky, 'warehouse', 'production', 'retail'
  bool _loading = true;
  bool _isCardView = false; // false = table view, true = card view
  final TextEditingController _searchController = TextEditingController();
  
  // Quick filters
  Set<String> _activeQuickFilters = {}; // 'low_stock', 'no_stock', 'recycling_fee', 'with_image', 'active', 'inactive'
  
  // Advanced filters
  Map<String, dynamic> _advancedFilters = {}; // 'purchase_price_min', 'purchase_price_max', 'sale_price_min', 'sale_price_max', 'stock_min', 'stock_max', 'supplier_id', 'date_from', 'date_to'
  
  // Bulk operations
  Set<int> _selectedMaterials = {}; // IDs of selected materials
  bool _isBulkSelectionMode = false;
  
  // Advanced view
  bool _showOnlyWithImages = false;
  String _viewMode = 'normal'; // 'compact', 'normal', 'expanded'
  
  // Price display settings
  bool _showPurchasePriceWithVat = true; // true = s DPH, false = bez DPH
  bool _showSalePriceWithVat = true; // true = s DPH, false = bez DPH
  
  // Column visibility settings
  bool _showColumnId = true; // ID stĺpec - predvolene viditeľný
  bool _showColumnName = true;
  bool _showColumnType = false; // Predvolene skrytý
  bool _showColumnCategory = false; // Predvolene skrytý
  bool _showColumnPLU = true;
  bool _showColumnEAN = true;
  bool _showColumnPurchase = true;
  bool _showColumnSale = true;
  bool _showColumnVat = false; // DPH stĺpec
  bool _showColumnMargin = true; // Marža stĺpec - predvolene viditeľný
  bool _showColumnStock = true;
  bool _showColumnLastPurchasePrice = true; // Posledná nákupná cena - predvolene viditeľný
  
  // Sorting
  String? _sortColumn; // null = no sort, 'name', 'type', 'category', 'plu', 'ean', 'purchase', 'sale', 'margin', 'stock'
  bool _sortAscending = true; // true = ascending, false = descending
  List<_SortConfig> _sortConfigs = []; // Multiple sort configs

  @override
  void initState() {
    super.initState();
    _loadSortPreferences();
    _loadMaterials();
    _searchController.addListener(_onSearchChanged);
  }
  
  Future<void> _loadSortPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortColumn = prefs.getString('warehouse_sort_column');
      final sortAscending = prefs.getBool('warehouse_sort_ascending') ?? true;
      setState(() {
        _sortColumn = sortColumn;
        _sortAscending = sortAscending;
      });
    } catch (e) {
      // Ignore errors
    }
  }
  
  Future<void> _saveSortPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_sortColumn != null) {
        await prefs.setString('warehouse_sort_column', _sortColumn!);
        await prefs.setBool('warehouse_sort_ascending', _sortAscending);
      } else {
        await prefs.remove('warehouse_sort_column');
        await prefs.remove('warehouse_sort_ascending');
      }
    } catch (e) {
      // Ignore errors
    }
  }
  
  Future<void> _loadViewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _viewMode = prefs.getString('warehouse_view_mode') ?? 'normal';
      _showOnlyWithImages = prefs.getBool('warehouse_show_only_with_images') ?? false;
    } catch (e) {
      // Ignore errors
    }
  }
  
  Future<void> _saveViewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('warehouse_view_mode', _viewMode);
      await prefs.setBool('warehouse_show_only_with_images', _showOnlyWithImages);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _handleMenuAction(String? result, Material material) async {
    if (result == 'edit') {
      await _editMaterial(material);
    } else if (result == 'delete') {
      await _deleteMaterial(material);
    }
  }

  Future<void> _editMaterial(Material material) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaterialScreen(materialToEdit: material),
      ),
    );
    if (result == true) {
      _loadMaterials();
    }
  }

  Future<void> _deleteMaterial(Material material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdiť vymazanie'),
        content: Text('Naozaj chcete vymazať materiál "${material.name}"? Táto akcia je nezvratná.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        await dbProvider.deleteMaterial(material.id!);
        
        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Materiál "${material.name}" bol úspešne vymazaný'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                left: 16,
                right: 16,
              ),
            ),
          );
          _loadMaterials();
        }
      } catch (e) {
        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba pri vymazávaní: $e'),
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
  }

  Future<void> _loadMaterials() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final lowStock = await dbProvider.checkLowStock();
    
    // Fetch last purchase movements for all materials
    final Map<int, StockMovement?> lastPurchaseMovements = {};
    for (final material in materials) {
      if (material.id != null) {
        lastPurchaseMovements[material.id!] = await dbProvider.getLastPurchaseMovement(material.id!);
      }
    }
    
    setState(() {
      _materials = materials;
      _lowStockMaterials = lowStock;
      _lastPurchaseMovements = lastPurchaseMovements;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    var filtered = _materials;

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((m) => m.category == _selectedCategoryFilter).toList();
    }

    // Apply quick filters
    if (_activeQuickFilters.contains('low_stock')) {
      filtered = filtered.where((m) => m.currentStock <= m.minStock).toList();
    }
    if (_activeQuickFilters.contains('no_stock')) {
      filtered = filtered.where((m) => m.currentStock == 0).toList();
    }
    if (_activeQuickFilters.contains('recycling_fee')) {
      filtered = filtered.where((m) => m.hasRecyclingFee && m.recyclingFee != null).toList();
    }
    // Note: 'with_image' and 'active'/'inactive' filters will be added when Material model is extended
    if (_showOnlyWithImages) {
      // Filter by imagePath when Material model is extended
      // filtered = filtered.where((m) => m.imagePath != null && m.imagePath!.isNotEmpty).toList();
    }

    // Apply advanced filters
    if (_advancedFilters.containsKey('purchase_price_min')) {
      final min = _advancedFilters['purchase_price_min'] as double?;
      if (min != null) {
        filtered = filtered.where((m) {
          final price = _showPurchasePriceWithVat 
              ? (m.averagePurchasePriceWithVat ?? 0.0)
              : (m.averagePurchasePriceWithoutVat ?? 0.0);
          return price >= min;
        }).toList();
      }
    }
    if (_advancedFilters.containsKey('purchase_price_max')) {
      final max = _advancedFilters['purchase_price_max'] as double?;
      if (max != null) {
        filtered = filtered.where((m) {
          final price = _showPurchasePriceWithVat 
              ? (m.averagePurchasePriceWithVat ?? 0.0)
              : (m.averagePurchasePriceWithoutVat ?? 0.0);
          return price <= max;
        }).toList();
      }
    }
    if (_advancedFilters.containsKey('sale_price_min')) {
      final min = _advancedFilters['sale_price_min'] as double?;
      if (min != null) {
        filtered = filtered.where((m) {
          final price = _showSalePriceWithVat
              ? (m.salePrice ?? 0.0) * (1 + (m.vatRate ?? 0) / 100)
              : (m.salePrice ?? 0.0);
          return price >= min;
        }).toList();
      }
    }
    if (_advancedFilters.containsKey('sale_price_max')) {
      final max = _advancedFilters['sale_price_max'] as double?;
      if (max != null) {
        filtered = filtered.where((m) {
          final price = _showSalePriceWithVat
              ? (m.salePrice ?? 0.0) * (1 + (m.vatRate ?? 0) / 100)
              : (m.salePrice ?? 0.0);
          return price <= max;
        }).toList();
      }
    }
    if (_advancedFilters.containsKey('stock_min')) {
      final min = _advancedFilters['stock_min'] as double?;
      if (min != null) {
        filtered = filtered.where((m) => m.currentStock >= min).toList();
      }
    }
    if (_advancedFilters.containsKey('stock_max')) {
      final max = _advancedFilters['stock_max'] as double?;
      if (max != null) {
        filtered = filtered.where((m) => m.currentStock <= max).toList();
      }
    }
    if (_advancedFilters.containsKey('supplier_id')) {
      final supplierId = _advancedFilters['supplier_id'] as int?;
      if (supplierId != null) {
        filtered = filtered.where((m) => m.defaultSupplierId == supplierId).toList();
      }
    }
    if (_advancedFilters.containsKey('date_from') || _advancedFilters.containsKey('date_to')) {
      final dateFrom = _advancedFilters['date_from'] as String?;
      final dateTo = _advancedFilters['date_to'] as String?;
      if (dateFrom != null || dateTo != null) {
        filtered = filtered.where((m) {
          final updatedAt = DateTime.tryParse(m.updatedAt);
          if (updatedAt == null) return false;
          if (dateFrom != null) {
            final from = DateTime.tryParse(dateFrom);
            if (from != null && updatedAt.isBefore(from)) return false;
          }
          if (dateTo != null) {
            final to = DateTime.tryParse(dateTo);
            if (to != null && updatedAt.isAfter(to.add(const Duration(days: 1)))) return false;
          }
          return true;
        }).toList();
      }
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((m) {
        final name = m.name.toLowerCase();
        final type = _getMaterialTypeName(m.type).toLowerCase();
        final category = _getCategoryName(m.category).toLowerCase();
        final plu = (m.pluCode ?? '').toLowerCase();
        final ean = (m.eanCode ?? '').toLowerCase();
        final warehouseNumber = (m.warehouseNumber ?? '').toLowerCase();
        
        return name.contains(searchQuery) ||
               type.contains(searchQuery) ||
               category.contains(searchQuery) ||
               plu.contains(searchQuery) ||
               ean.contains(searchQuery) ||
               warehouseNumber.contains(searchQuery);
      }).toList();
    }

    // Apply sorting
    filtered = _sortMaterials(filtered);

    setState(() {
      _filteredMaterials = filtered;
    });
  }
  
  List<Material> _sortMaterials(List<Material> materials) {
    if (_sortColumn == null && _sortConfigs.isEmpty) {
      return materials;
    }
    
    final sorted = List<Material>.from(materials);
    
    // Use multiple sort configs if available, otherwise use single sort
    if (_sortConfigs.isNotEmpty) {
      sorted.sort((a, b) {
        for (final config in _sortConfigs) {
          final comparison = _compareMaterials(a, b, config.column, config.ascending);
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    } else if (_sortColumn != null) {
      sorted.sort((a, b) => _compareMaterials(a, b, _sortColumn!, _sortAscending));
    }
    
    return sorted;
  }
  
  int _compareMaterials(Material a, Material b, String column, bool ascending) {
    int result = 0;
    
    switch (column) {
      case 'id':
        // Sort by warehouseNumber first, then by id
        final idA = a.warehouseNumber ?? (a.id != null ? a.id.toString() : '');
        final idB = b.warehouseNumber ?? (b.id != null ? b.id.toString() : '');
        result = idA.compareTo(idB);
        break;
      case 'name':
        result = a.name.compareTo(b.name);
        break;
      case 'type':
        result = a.type.compareTo(b.type);
        break;
      case 'category':
        result = a.category.compareTo(b.category);
        break;
      case 'plu':
        final pluA = a.pluCode ?? '';
        final pluB = b.pluCode ?? '';
        result = pluA.compareTo(pluB);
        break;
      case 'ean':
        final eanA = a.eanCode ?? '';
        final eanB = b.eanCode ?? '';
        result = eanA.compareTo(eanB);
        break;
      case 'purchase':
        final priceA = _showPurchasePriceWithVat 
            ? (a.averagePurchasePriceWithVat ?? 0.0)
            : (a.averagePurchasePriceWithoutVat ?? 0.0);
        final priceB = _showPurchasePriceWithVat
            ? (b.averagePurchasePriceWithVat ?? 0.0)
            : (b.averagePurchasePriceWithoutVat ?? 0.0);
        result = priceA.compareTo(priceB);
        break;
      case 'sale':
        final saleA = _showSalePriceWithVat
            ? (a.salePrice ?? 0.0) * (1 + (a.vatRate ?? 0) / 100)
            : (a.salePrice ?? 0.0);
        final saleB = _showSalePriceWithVat
            ? (b.salePrice ?? 0.0) * (1 + (b.vatRate ?? 0) / 100)
            : (b.salePrice ?? 0.0);
        result = saleA.compareTo(saleB);
        break;
      case 'margin':
        final purchaseA = a.averagePurchasePriceWithVat ?? 0.0;
        final saleA = a.salePrice ?? 0.0;
        final marginA = saleA > 0 ? ((saleA - purchaseA) / saleA * 100) : 0.0;
        final purchaseB = b.averagePurchasePriceWithVat ?? 0.0;
        final saleB = b.salePrice ?? 0.0;
        final marginB = saleB > 0 ? ((saleB - purchaseB) / saleB * 100) : 0.0;
        result = marginA.compareTo(marginB);
        break;
      case 'stock':
        result = a.currentStock.compareTo(b.currentStock);
        break;
      default:
        return 0;
    }
    
    return ascending ? result : -result;
  }
  
  void _handleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        // Toggle direction if same column
        _sortAscending = !_sortAscending;
      } else {
        // New column, start with ascending
        _sortColumn = column;
        _sortAscending = true;
      }
      _saveSortPreferences();
      _applyFilters();
    });
  }

  void _applyCategoryFilter() {
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // HEADER - Hlava
          _buildHeader(context),
          
          // BULK ACTIONS BAR (if in bulk selection mode)
          if (_isBulkSelectionMode && _selectedMaterials.isNotEmpty)
            _buildBulkActionsBar(),
          
          // BODY - Telo
          Expanded(
            child: NotificationListener<WarehouseNavigateNotification>(
              onNotification: (n) {
                setState(() => _selectedIndex = n.tabIndex);
                if (n.tabIndex == 1 && n.approvalsMode != null) {
                  _pendingKey.currentState?.setMode(n.approvalsMode!);
                }
                return true;
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildStockOverview(),
                        ReceiptsPendingScreen(key: _pendingKey),
                        const BulkReceiptScreen(),
                        const IssueScreen(),
                        const InventoryScreen(),
                        const MovementsHistoryScreen(),
                        const SuppliersScreen(),
                        const CustomersScreen(),
                        const AutoOrdersScreen(),
                        const WarehouseClosingsScreen(),
                        const WarehousesScreen(),
                      ],
                    ),
            ),
          ),
          
          // FOOTER - Päta
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade700,
            Colors.green.shade500,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warehouse,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skladové hospodárstvo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, d. MMMM yyyy', 'sk_SK').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.home, color: Colors.white),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    tooltip: 'Úvodná stránka',
                  ),
                  if (_selectedIndex == 0)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateMaterialScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadMaterials();
                        }
                      },
                      tooltip: 'Nová skladová položka',
                    ),
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: () async {
                      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                      await syncProvider.syncAll();
                      _loadMaterials();
                    },
                      tooltip: 'Synchronizovať',
                  ),
                  IconButton(
                    icon: const Icon(Icons.inventory_2, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PalletReceiveScreen(),
                        ),
                      );
                    },
                    tooltip: 'Naskladniť palety',
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart),
                    color: Colors.white,
                    onPressed: () => _showStatisticsCharts(),
                    tooltip: 'Grafy a štatistiky',
                  ),
                ],
              ),
            ),
            // Quick stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    'Položky',
                    '${_materials.length}',
                    Icons.inventory_2,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildLowStockDropdown(
                    context,
                    'Nízky stav',
                    '${_lowStockMaterials.length}',
                    badgeCount: _lowStockMaterials.length,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildStatItem(
                    context,
                    'Celkový stav',
                    _calculateTotalStock(),
                    Icons.assessment,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildStatItem(
                    context,
                    'Hodnota skladu',
                    _calculateTotalStockValue(),
                    Icons.euro,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: (color ?? Colors.white).withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockDropdown(BuildContext context, String label, String value, {int badgeCount = 0}) {
    final hasLowStock = _lowStockMaterials.isNotEmpty;
    final color = hasLowStock ? Colors.orange : Colors.white;
    
    return PopupMenuButton<String>(
      enabled: hasLowStock,
      child: MouseRegion(
        cursor: hasLowStock ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.warning, color: color, size: 20),
                if (hasLowStock)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: color,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
                if (hasLowStock) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    color: color.withOpacity(0.8),
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        if (!hasLowStock) {
          return [
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('Žiadne upozornenia'),
            ),
          ];
        }
        
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upozornenie na nedostatok',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _lowStockMaterials.map((material) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  material.name,
                                  style: TextStyle(
                                    color: Colors.grey.shade900,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${material.currentStock.toStringAsFixed(1)} / ${material.minStock.toStringAsFixed(1)} ${material.unit}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _calculateTotalStock() {
    if (_materials.isEmpty) return '0';
    final total = _materials.fold<double>(0, (sum, m) => sum + m.currentStock);
    return total.toStringAsFixed(0);
  }

  String _calculateTotalStockValue() {
    if (_materials.isEmpty) return '0.00 €';
    final total = _materials.fold<double>(0, (sum, m) {
      // Use purchase price with VAT if available, otherwise 0
      final price = m.averagePurchasePriceWithVat ?? 0.0;
      return sum + (m.currentStock * price);
    });
    return '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(total)}';
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${_selectedMaterials.length} vybraných',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showBulkReceiptDialog(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Hromadný príjem'),
          ),
          TextButton.icon(
            onPressed: () => _showBulkIssueDialog(),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Hromadný výdaj'),
          ),
          TextButton.icon(
            onPressed: () => _showBulkCategoryDialog(),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Zmeniť kategóriu'),
          ),
          TextButton.icon(
            onPressed: () => _exportSelectedMaterials(),
            icon: const Icon(Icons.download),
            label: const Text('Exportovať'),
          ),
          TextButton.icon(
            onPressed: () => _showBulkDeleteDialog(),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Vymazať'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showBulkReceiptDialog() async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hromadný príjem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pridá ${_selectedMaterials.length} položiek'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Množstvo',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Cena (bez DPH)',
                border: OutlineInputBorder(),
                prefixText: '€ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              final price = double.tryParse(priceController.text);
              if (quantity != null && quantity > 0 && price != null && price >= 0) {
                await _performBulkReceipt(quantity, price);
                Navigator.pop(context);
              }
            },
            child: const Text('Pridať'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performBulkReceipt(double quantity, double price) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    // Implementation would create stock movements for each selected material
    // This is a simplified version
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hromadný príjem pre ${_selectedMaterials.length} položiek'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
  
  Future<void> _showBulkIssueDialog() async {
    final quantityController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hromadný výdaj'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Odoberie ${_selectedMaterials.length} položiek'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Množstvo',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                await _performBulkIssue(quantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Odobrať'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performBulkIssue(double quantity) async {
    // Implementation would create stock movements for each selected material
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hromadný výdaj pre ${_selectedMaterials.length} položiek'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
  
  Future<void> _showBulkCategoryDialog() async {
    String? selectedCategory;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zmeniť kategóriu'),
          content: DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategória',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'warehouse', child: Text('Sklad')),
              DropdownMenuItem(value: 'production', child: Text('Výroba')),
              DropdownMenuItem(value: 'retail', child: Text('Maloobchod')),
              DropdownMenuItem(value: 'overhead', child: Text('Režijný')),
            ],
            onChanged: (value) {
              setDialogState(() {
                selectedCategory = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: selectedCategory != null
                  ? () async {
                      await _performBulkCategoryChange(selectedCategory!);
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Zmeniť'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _performBulkCategoryChange(String category) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    for (final materialId in _selectedMaterials) {
      final material = await dbProvider.getMaterial(materialId);
      if (material != null) {
        final updated = material.copyWith(category: category);
        await dbProvider.updateMaterial(updated);
      }
    }
    setState(() {
      _isBulkSelectionMode = false;
      _selectedMaterials.clear();
    });
    _loadMaterials();
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kategória bola zmenená'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
  
  Future<void> _exportSelectedMaterials() async {
    final selected = _filteredMaterials
        .where((m) => m.id != null && _selectedMaterials.contains(m.id))
        .toList();
    await _exportMaterials(selected, 'selected');
  }
  
  Future<void> _showExportDialog() async {
    final exportService = ExportService();
    String selectedFormat = 'excel';
    Set<String> selectedColumns = {
      'name',
      'current_stock',
      'min_stock',
      'unit',
      'purchase_price',
      'sale_price',
    };
    String exportScope = 'filtered'; // 'all', 'filtered', 'selected'
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download),
              SizedBox(width: 8),
              Text('Export dát'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formát:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'excel', label: Text('Excel')),
                    ButtonSegment(value: 'csv', label: Text('CSV')),
                  ],
                  selected: {selectedFormat},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() {
                      selectedFormat = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rozsah:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'all',
                      label: Text('Všetky (${_materials.length})'),
                    ),
                    ButtonSegment(
                      value: 'filtered',
                      label: Text('Vyfiltrované (${_filteredMaterials.length})'),
                    ),
                    if (_selectedMaterials.isNotEmpty)
                      ButtonSegment(
                        value: 'selected',
                        label: Text('Vybrané (${_selectedMaterials.length})'),
                      ),
                  ],
                  selected: {exportScope},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() {
                      exportScope = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Stĺpce:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'name', 'type', 'category', 'plu', 'ean',
                    'current_stock', 'min_stock', 'unit',
                    'purchase_price', 'sale_price', 'vat_rate', 'margin',
                    'warehouse_number', 'recycling_fee',
                  ].map((col) {
                    final isSelected = selectedColumns.contains(col);
                    return FilterChip(
                      label: Text(_getExportColumnLabel(col)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedColumns.add(col);
                          } else {
                            selectedColumns.remove(col);
                          }
                        });
                      },
                    );
                  }).toList(),
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
              onPressed: () async {
                List<Material> materialsToExport;
                switch (exportScope) {
                  case 'all':
                    materialsToExport = _materials;
                    break;
                  case 'filtered':
                    materialsToExport = _filteredMaterials;
                    break;
                  case 'selected':
                    materialsToExport = _filteredMaterials
                        .where((m) => m.id != null && _selectedMaterials.contains(m.id))
                        .toList();
                    break;
                  default:
                    materialsToExport = _filteredMaterials;
                }
                
                final filePath = await exportService.exportMaterials(
                  materialsToExport,
                  selectedColumns: selectedColumns.toList(),
                  format: selectedFormat,
                );
                Navigator.pop(context);
                final mediaQuery = MediaQuery.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export ${materialsToExport.length} položiek dokončený'),
                        const SizedBox(height: 4),
                        Text(
                          'Súbor uložený: $filePath',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                      left: 16,
                      right: 16,
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('Exportovať'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getExportColumnLabel(String column) {
    switch (column) {
      case 'name':
        return 'Názov';
      case 'type':
        return 'Typ';
      case 'category':
        return 'Kategória';
      case 'plu':
        return 'PLU';
      case 'ean':
        return 'EAN';
      case 'current_stock':
        return 'Stav';
      case 'min_stock':
        return 'Min. stav';
      case 'unit':
        return 'Jednotka';
      case 'purchase_price':
        return 'Nákup';
      case 'sale_price':
        return 'Predaj';
      case 'vat_rate':
        return 'DPH';
      case 'margin':
        return 'Marža';
      case 'warehouse_number':
        return 'Sklad. č.';
      case 'recycling_fee':
        return 'Recyklácia';
      default:
        return column;
    }
  }
  
  Future<void> _exportMaterials(List<Material> materials, String scope) async {
    final exportService = ExportService();
    final filePath = await exportService.exportMaterials(materials);
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export ${materials.length} položiek dokončený'),
            const SizedBox(height: 4),
            Text(
              'Súbor uložený: $filePath',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  void _showMaterialQuickActions(Material material) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Rýchly príjem'),
              onTap: () {
                Navigator.pop(context);
                _showQuickReceiptDialog(material);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle),
              title: const Text('Rýchly výdaj'),
              onTap: () {
                Navigator.pop(context);
                _showQuickIssueDialog(material);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Zmeniť cenu'),
              onTap: () {
                Navigator.pop(context);
                _showQuickPriceDialog(material);
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_down),
              title: const Text('Upraviť minimálny stav'),
              onTap: () {
                Navigator.pop(context);
                _showQuickMinStockDialog(material);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Detail'),
              onTap: () {
                Navigator.pop(context);
                _showMaterialDetail(material);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMaterialDetail(Material material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _MaterialDetailPanel(
          material: material,
          scrollController: scrollController,
        ),
      ),
    );
  }
  
  Future<void> _showQuickReceiptDialog(Material material) async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: material.averagePurchasePriceWithoutVat?.toStringAsFixed(2) ?? '',
    );
    Warehouse? selectedWarehouse;
    List<Warehouse> warehouses = [];
    
    // Load warehouses
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    warehouses = await dbProvider.getWarehouses(activeOnly: true);
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Rýchly príjem: ${material.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Množstvo',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Cena (bez DPH)',
                  border: OutlineInputBorder(),
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Warehouse>(
                value: selectedWarehouse,
                decoration: const InputDecoration(
                  labelText: 'Sklad *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warehouse),
                ),
                items: warehouses.map((warehouse) {
                  return DropdownMenuItem<Warehouse>(
                    value: warehouse,
                    child: Text(warehouse.name),
                  );
                }).toList(),
                onChanged: (warehouse) {
                  setDialogState(() {
                    selectedWarehouse = warehouse;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = double.tryParse(quantityController.text);
                final price = double.tryParse(priceController.text);
                if (quantity != null && quantity > 0 && price != null && price >= 0 && selectedWarehouse != null) {
                  await _performQuickReceipt(material, quantity, price, selectedWarehouse!.id);
                  Navigator.pop(context);
                }
              },
              child: const Text('Pridať'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _performQuickReceipt(Material material, double quantity, double priceWithoutVat, int? warehouseId) async {
    if (material.id == null) return;
    
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final vatRate = material.vatRate ?? 20.0;
    final priceWithVat = priceWithoutVat * (1 + vatRate / 100);
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    
    // Create stock movement with type "receipt" and notes "Rýchly príjem"
    final movement = StockMovement(
      movementType: 'receipt',
      materialId: material.id,
      quantity: quantity,
      unit: material.unit,
      purchasePriceWithoutVat: priceWithoutVat,
      purchasePriceWithVat: priceWithVat,
      vatRate: vatRate,
      warehouseId: warehouseId,
      movementDate: DateFormat('yyyy-MM-dd').format(now),
      createdBy: 'system', // TODO: Get actual user
      status: 'approved', // Auto-approve quick receipts
      notes: 'Rýchly príjem',
      createdAt: nowStr,
    );
    
    // Insert stock movement (returns the ID)
    final movementId = await dbProvider.insertStockMovement(movement);
    
    // Approve the movement to trigger weighted average calculation
    await dbProvider.approveStockMovement(
      movementId,
      'system', // TODO: Get actual user
    );
    
    // Get updated material to calculate new sale price
    final updatedMaterial = await dbProvider.getMaterial(material.id!);
    if (updatedMaterial != null && updatedMaterial.averagePurchasePriceWithVat != null) {
      // Calculate new sale price based on weighted average purchase price
      // Use a default margin of 20% (can be adjusted)
      final margin = 0.20; // 20% margin
      final newSalePrice = updatedMaterial.averagePurchasePriceWithVat! * (1 + margin);
      
      // Update material with new sale price
      await dbProvider.updateMaterial(
        updatedMaterial.copyWith(
          salePrice: newSalePrice,
          updatedAt: nowStr,
        ),
      );
    }
    
    _loadMaterials();
    
    // Show success message and option to print PDF
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rýchly príjem ${quantity} ${material.unit} ${material.name} bol zaznamenaný'),
          action: SnackBarAction(
            label: 'Zobraziť PDF',
            onPressed: () async {
              final receipt = await dbProvider.getStockMovement(movementId);
              if (receipt != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptPrintScreen(
                      receipt: receipt,
                      material: updatedMaterial,
                    ),
                  ),
                );
              }
            },
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  Future<void> _showQuickIssueDialog(Material material) async {
    final quantityController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rýchly výdaj: ${material.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aktuálny stav: ${material.currentStock.toStringAsFixed(1)} ${material.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Množstvo',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                await _performQuickIssue(material, quantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Odobrať'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performQuickIssue(Material material, double quantity) async {
    // Create stock movement
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Výdaj ${quantity} ${material.unit} ${material.name}'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
    _loadMaterials();
  }
  
  Future<void> _showQuickPriceDialog(Material material) async {
    // salePrice is stored without VAT, so we show it as is
    final currentPrice = material.salePrice ?? 0.0;
    final priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zmeniť cenu: ${material.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (material.salePrice != null) ...[
              Text(
                'Aktuálna cena bez DPH: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.salePrice)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (material.vatRate != null)
                Text(
                  'Aktuálna cena s DPH: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.salePrice! * (1 + material.vatRate! / 100))}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Predajná cena (bez DPH)',
                border: OutlineInputBorder(),
                prefixText: '€ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            if (material.vatRate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cena s DPH (${material.vatRate!.toStringAsFixed(1)}%): bude vypočítaná automaticky',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text);
              if (price != null && price >= 0) {
                await _performQuickPriceChange(material, price);
                Navigator.pop(context);
              }
            },
            child: const Text('Zmeniť'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performQuickPriceChange(Material material, double price) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    // salePrice is stored without VAT, so we save it directly
    final updated = material.copyWith(salePrice: price);
    await dbProvider.updateMaterial(updated);
    _loadMaterials();
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cena bola zmenená na ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)} bez DPH',
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
  
  Future<void> _showQuickMinStockDialog(Material material) async {
    final minStockController = TextEditingController(
      text: material.minStock.toStringAsFixed(1),
    );
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upraviť minimálny stav: ${material.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aktuálny stav: ${material.currentStock.toStringAsFixed(1)} ${material.unit}'),
            const SizedBox(height: 16),
            TextField(
              controller: minStockController,
              decoration: InputDecoration(
                labelText: 'Minimálny stav (${material.unit})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () async {
              final minStock = double.tryParse(minStockController.text);
              if (minStock != null && minStock >= 0) {
                await _performQuickMinStockChange(material, minStock);
                Navigator.pop(context);
              }
            },
            child: const Text('Zmeniť'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performQuickMinStockChange(Material material, double minStock) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final updated = material.copyWith(minStock: minStock);
    await dbProvider.updateMaterial(updated);
    _loadMaterials();
    final mediaQuery = MediaQuery.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Minimálny stav bol zmenený'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
  
  Future<void> _showStatisticsCharts() async {
    await showDialog(
      context: context,
      builder: (context) => _StatisticsChartsDialog(materials: _materials),
    );
  }
  
  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QrCodeScreen(),
      ),
    );
    
    if (result != null && mounted) {
      _searchController.text = result;
      _applyFilters();
      _saveSearchHistory(result);
    }
  }
  
  Future<void> _showSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('warehouse_search_history') ?? [];
    
    if (history.isEmpty) {
      // Ensure we use the correct context for the Scaffold
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Žiadna história vyhľadávaní'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
           bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            
            left: 16,
            
            right: 16,
          ),
          duration: const Duration(seconds: 2),
          
        ),
        
      );
      return;
    }
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('História vyhľadávaní'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  _searchController.text = query;
                  _applyFilters();
                  Navigator.pop(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    history.removeAt(index);
                    await prefs.setStringList('warehouse_search_history', history);
                    Navigator.pop(context);
                    _showSearchHistory();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.remove('warehouse_search_history');
              Navigator.pop(context);
            },
            child: const Text('Vymazať históriu'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('warehouse_search_history') ?? [];
      
      // Remove if already exists
      history.remove(query);
      // Add to beginning
      history.insert(0, query);
      // Keep only last 20
      if (history.length > 20) {
        history.removeRange(20, history.length);
      }
      
      await prefs.setStringList('warehouse_search_history', history);
    } catch (e) {
      // Ignore errors
    }
  }
  
  String _getViewModeLabel() {
    switch (_viewMode) {
      case 'compact':
        return 'Kompaktný';
      case 'expanded':
        return 'Rozšírený';
      default:
        return 'Normálny';
    }
  }
  
  Future<void> _showViewModeDialog() async {
    String? selectedMode = _viewMode;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Režim zobrazenia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Kompaktný'),
                subtitle: const Text('Menšie paddingy a fonty'),
                value: 'compact',
                groupValue: selectedMode,
                onChanged: (value) {
                  setDialogState(() {
                    selectedMode = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Normálny'),
                subtitle: const Text('Štandardné zobrazenie'),
                value: 'normal',
                groupValue: selectedMode,
                onChanged: (value) {
                  setDialogState(() {
                    selectedMode = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Rozšírený'),
                subtitle: const Text('Viac detailov v tabuľke'),
                value: 'expanded',
                groupValue: selectedMode,
                onChanged: (value) {
                  setDialogState(() {
                    selectedMode = value;
                  });
                },
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
                setState(() {
                  _viewMode = selectedMode ?? 'normal';
                  _saveViewPreferences();
                });
                Navigator.pop(context);
              },
              child: const Text('Použiť'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showBulkDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdiť vymazanie'),
        content: Text('Naozaj chcete vymazať ${_selectedMaterials.length} položiek? Táto akcia je nezvratná.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      for (final materialId in _selectedMaterials) {
        await dbProvider.deleteMaterial(materialId);
      }
      setState(() {
        _isBulkSelectionMode = false;
        _selectedMaterials.clear();
      });
      _loadMaterials();
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Položky boli vymazané'),
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

  Widget _buildFooter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              _loadMaterials();
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse),
              label: 'Prehľad',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pending_outlined),
              activeIcon: Icon(Icons.pending),
              label: 'Na schválenie',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.arrow_downward_outlined),
              activeIcon: Icon(Icons.arrow_downward),
              label: 'Príjem',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.arrow_upward_outlined),
              activeIcon: Icon(Icons.arrow_upward),
              label: 'Výdaj',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventúra',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'História',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Dodávatelia',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Zákazníci',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Objednávky',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lock_outline),
              activeIcon: Icon(Icons.lock),
              label: 'Uzávierky',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse),
              label: 'Sklady',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockOverview() {
    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Materials list header with filters
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Skladové položky',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isCardView ? Icons.table_chart : Icons.view_module),
                        onPressed: () {
                          setState(() {
                            _isCardView = !_isCardView;
                          });
                        },
                        tooltip: _isCardView ? 'Tabuľkové zobrazenie' : 'Kartové zobrazenie',
                      ),
                      IconButton(
                        icon: const Icon(Icons.print),
                        onPressed: () => _showPrintDialog(),
                        tooltip: 'Tlačiť zásoby',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _showExportDialog(),
                        tooltip: 'Exportovať do Excelu/CSV',
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateMaterialScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadMaterials();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nová položka'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search field with QR scanner
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Vyhľadať',
                        hintText: 'Názov, typ, kategória, PLU, EAN, sklad. číslo...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () => _scanQrCode(),
                    tooltip: 'Skenovať QR kód',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: () => _showSearchHistory(),
                    tooltip: 'História vyhľadávaní',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick filter chips
              _buildQuickFilterChips(),
              const SizedBox(height: 12),
              // Category filter dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                value: _selectedCategoryFilter,
                decoration: InputDecoration(
                  labelText: 'Kategória',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.filter_list),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.all_inclusive, size: 20),
                        SizedBox(width: 8),
                        Text('Všetky'),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'warehouse',
                    child: Row(
                      children: [
                        Icon(Icons.warehouse, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Sklad'),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'production',
                    child: Row(
                      children: [
                        Icon(Icons.factory, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Výroba'),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'retail',
                    child: Row(
                      children: [
                        Icon(Icons.store, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Maloobchod'),
                      ],
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'overhead',
                    child: Row(
                      children: [
                        Icon(Icons.storage, size: 20, color: const Color.fromARGB(255, 33, 199, 69)),
                        const SizedBox(width: 8),
                        const Text('Režijný'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryFilter = value;
                    _applyCategoryFilter();
                  });
                },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _advancedFilters.isNotEmpty ? Icons.filter_alt : Icons.filter_alt_outlined,
                      color: _advancedFilters.isNotEmpty ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onPressed: () => _showAdvancedFiltersDialog(),
                    tooltip: 'Pokročilé filtre',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_filteredMaterials.length} položiek',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Materials view (table or cards)
          _isCardView ? _buildCardView() : _buildTableView(),
        ],
      ),
    );
  }

  Future<void> _showAdvancedFiltersDialog() async {
    final purchasePriceMinController = TextEditingController(
      text: _advancedFilters['purchase_price_min']?.toString() ?? '',
    );
    final purchasePriceMaxController = TextEditingController(
      text: _advancedFilters['purchase_price_max']?.toString() ?? '',
    );
    final salePriceMinController = TextEditingController(
      text: _advancedFilters['sale_price_min']?.toString() ?? '',
    );
    final salePriceMaxController = TextEditingController(
      text: _advancedFilters['sale_price_max']?.toString() ?? '',
    );
    final stockMinController = TextEditingController(
      text: _advancedFilters['stock_min']?.toString() ?? '',
    );
    final stockMaxController = TextEditingController(
      text: _advancedFilters['stock_max']?.toString() ?? '',
    );
    
    int? selectedSupplierId = _advancedFilters['supplier_id'] as int?;
    DateTime? dateFrom = _advancedFilters['date_from'] != null 
        ? DateTime.tryParse(_advancedFilters['date_from'] as String)
        : null;
    DateTime? dateTo = _advancedFilters['date_to'] != null
        ? DateTime.tryParse(_advancedFilters['date_to'] as String)
        : null;
    
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final suppliers = await dbProvider.getSuppliers();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.filter_alt),
              SizedBox(width: 8),
              Text('Pokročilé filtre'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rozsah cien (nákup):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: purchasePriceMinController,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(' - '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: purchasePriceMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rozsah cien (predaj):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: salePriceMinController,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(' - '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: salePriceMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rozsah stavu zásob:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockMinController,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(' - '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: stockMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dodávateľ:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: selectedSupplierId,
                  decoration: const InputDecoration(
                    labelText: 'Vyberte dodávateľa',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Všetci'),
                    ),
                    ...suppliers.map((supplier) => DropdownMenuItem<int?>(
                      value: supplier.id,
                      child: Text(supplier.name),
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedSupplierId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dátum poslednej zmeny:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dateFrom = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Od',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            dateFrom != null
                                ? DateFormat('dd.MM.yyyy').format(dateFrom!)
                                : 'Vyberte dátum',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dateTo ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dateTo = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Do',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            dateTo != null
                                ? DateFormat('dd.MM.yyyy').format(dateTo!)
                                : 'Vyberte dátum',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                purchasePriceMinController.dispose();
                purchasePriceMaxController.dispose();
                salePriceMinController.dispose();
                salePriceMaxController.dispose();
                stockMinController.dispose();
                stockMaxController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Zrušiť'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _advancedFilters.clear();
                });
                purchasePriceMinController.dispose();
                purchasePriceMaxController.dispose();
                salePriceMinController.dispose();
                salePriceMaxController.dispose();
                stockMinController.dispose();
                stockMaxController.dispose();
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Vymazať filtre'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _advancedFilters.clear();
                  
                  final purchaseMin = double.tryParse(purchasePriceMinController.text);
                  if (purchaseMin != null) {
                    _advancedFilters['purchase_price_min'] = purchaseMin;
                  }
                  final purchaseMax = double.tryParse(purchasePriceMaxController.text);
                  if (purchaseMax != null) {
                    _advancedFilters['purchase_price_max'] = purchaseMax;
                  }
                  final saleMin = double.tryParse(salePriceMinController.text);
                  if (saleMin != null) {
                    _advancedFilters['sale_price_min'] = saleMin;
                  }
                  final saleMax = double.tryParse(salePriceMaxController.text);
                  if (saleMax != null) {
                    _advancedFilters['sale_price_max'] = saleMax;
                  }
                  final stockMin = double.tryParse(stockMinController.text);
                  if (stockMin != null) {
                    _advancedFilters['stock_min'] = stockMin;
                  }
                  final stockMax = double.tryParse(stockMaxController.text);
                  if (stockMax != null) {
                    _advancedFilters['stock_max'] = stockMax;
                  }
                  if (selectedSupplierId != null) {
                    _advancedFilters['supplier_id'] = selectedSupplierId;
                  }
                  if (dateFrom != null) {
                    _advancedFilters['date_from'] = dateFrom!.toIso8601String().split('T')[0];
                  }
                  if (dateTo != null) {
                    _advancedFilters['date_to'] = dateTo!.toIso8601String().split('T')[0];
                  }
                });
                purchasePriceMinController.dispose();
                purchasePriceMaxController.dispose();
                salePriceMinController.dispose();
                salePriceMaxController.dispose();
                stockMinController.dispose();
                stockMaxController.dispose();
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Použiť'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickFilterChip(
          'Nízky stav',
          'low_stock',
          Icons.warning,
          Colors.orange,
        ),
        _buildQuickFilterChip(
          'Bez zásob',
          'no_stock',
          Icons.inventory_2_outlined,
          Colors.red,
        ),
        _buildQuickFilterChip(
          'S recyklačným poplatkom',
          'recycling_fee',
          Icons.recycling,
          Colors.green,
        ),
        // Note: 'with_image' and 'active'/'inactive' chips will be added when Material model is extended
      ],
    );
  }
  
  Widget _buildQuickFilterChip(String label, String filterKey, IconData icon, Color color) {
    final isActive = _activeQuickFilters.contains(filterKey);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isActive,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _activeQuickFilters.add(filterKey);
          } else {
            _activeQuickFilters.remove(filterKey);
          }
          _applyFilters();
        });
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : color,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isActive ? color : Colors.grey.shade300,
        width: isActive ? 2 : 1,
      ),
    );
  }

  Icon _getMaterialIcon(String type) {
    switch (type) {
      case 'cement':
        return const Icon(Icons.circle, color: Colors.grey);
      case 'aggregate':
        return const Icon(Icons.grain, color: Colors.brown);
      case 'water':
        return const Icon(Icons.water_drop, color: Colors.blue);
      case 'plasticizer':
        return const Icon(Icons.science, color: Colors.purple);
      default:
        return const Icon(Icons.inventory_2);
    }
  }

  Color _getMaterialColor(String type) {
    switch (type) {
      case 'cement':
        return Colors.grey;
      case 'aggregate':
        return Colors.brown;
      case 'water':
        return Colors.blue;
      case 'plasticizer':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _getMaterialTypeName(String type) {
    switch (type) {
      case 'cement':
        return 'Cement';
      case 'aggregate':
        return 'Štrk';
      case 'water':
        return 'Voda';
      case 'plasticizer':
        return 'Plastifikátor';
      default:
        return type;
    }
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
        return 'Režijný';
      default:
        return category;
    }
  }

  // Helper methods for price calculation
  double? _getPurchasePrice(Material material) {
    if (_showPurchasePriceWithVat) {
      return material.averagePurchasePriceWithVat;
    } else {
      return material.averagePurchasePriceWithoutVat;
    }
  }

  // Format purchase price with 4 decimal places for small values
  String _formatPurchasePrice(double? price) {
    if (price == null) return '-';
    if (price == 0) return '0.0000';
    
    // For very small prices (less than 0.01), show 4 decimal places
    if (price < 0.01) {
      return price.toStringAsFixed(4);
    }
    // For normal prices, show 2 decimal places
    return price.toStringAsFixed(2);
  }

  // Format date string to display format
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Format sale price with 2 decimal places
  String _formatSalePrice(double? price) {
    if (price == null) return '-';
    if (price == 0) return '0.00';
    return price.toStringAsFixed(2);
  }

  double? _getSalePrice(Material material) {
    // salePrice is stored WITHOUT VAT
    if (_showSalePriceWithVat) {
      // Calculate sale price WITH VAT
      if (material.salePrice != null && material.vatRate != null) {
        return material.salePrice! * (1 + material.vatRate! / 100);
      }
      return material.salePrice;
    } else {
      // Return sale price WITHOUT VAT (as stored)
      return material.salePrice;
    }
  }

  String _getPriceLabel(bool isPurchase) {
    if (isPurchase) {
      return _showPurchasePriceWithVat ? 'Nákup s DPH' : 'Nákup bez DPH';
    } else {
      return _showSalePriceWithVat ? 'Predaj s DPH' : 'Predaj bez DPH';
    }
  }

  // Calculate VAT amount in EUR
  double? _getVatAmount(Material material) {
    if (material.salePrice == null || material.vatRate == null) {
      return null;
    }
    // VAT = salePrice * (vatRate / (100 + vatRate))
    // Or: VAT = salePrice - (salePrice / (1 + vatRate/100))
    return material.salePrice! * (material.vatRate! / (100 + material.vatRate!));
  }

  // Calculate margin - absolute value in EUR
  double? _getMarginAmount(Material material) {
    final salePrice = _getSalePrice(material);
    final purchasePrice = _getPurchasePrice(material);
    
    if (salePrice == null || purchasePrice == null || purchasePrice == 0) {
      return null;
    }
    
    return salePrice - purchasePrice;
  }

  // Calculate margin percentage
  double? _getMarginPercentage(Material material) {
    final salePrice = _getSalePrice(material);
    final purchasePrice = _getPurchasePrice(material);
    
    if (salePrice == null || purchasePrice == null || purchasePrice == 0) {
      return null;
    }
    
    return ((salePrice - purchasePrice) / purchasePrice) * 100;
  }

  Widget _buildHeaderCellWithContextMenu(String text, {TextAlign textAlign = TextAlign.left, String? sortColumn}) {
    final isSorted = sortColumn != null && _sortColumn == sortColumn;
    final sortIcon = isSorted
        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.unfold_more;
    final sortColor = isSorted ? Theme.of(context).colorScheme.primary : Colors.grey;
    
    return GestureDetector(
      onTap: sortColumn != null ? () => _handleSort(sortColumn) : null,
      onSecondaryTap: () => _showColumnContextMenu(context, text),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisAlignment: textAlign == TextAlign.right 
              ? MainAxisAlignment.end 
              : (textAlign == TextAlign.center 
                  ? MainAxisAlignment.center 
                  : MainAxisAlignment.start),
          children: [
            if (textAlign == TextAlign.right) ...[
              if (sortColumn != null) ...[
                Icon(sortIcon, size: 16, color: sortColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  text,
                  textAlign: textAlign,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSorted ? sortColor : Colors.grey[800],
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  text,
                  textAlign: textAlign,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSorted ? sortColor : Colors.grey[800],
                  ),
                ),
              ),
              if (sortColumn != null) ...[
                const SizedBox(width: 4),
                Icon(sortIcon, size: 16, color: sortColor),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showColumnContextMenu(BuildContext context, String columnName) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    
    // Build menu items dynamically to reflect current state
    final List<PopupMenuEntry<dynamic>> items = [
      const PopupMenuItem<dynamic>(
        enabled: false,
        child: Row(
          children: [
            Icon(Icons.visibility),
            SizedBox(width: 8),
            Text('Zobraziť stĺpce'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      _buildColumnMenuItem('ID', _showColumnId, (value) {
        setState(() => _showColumnId = value);
      }),
      _buildColumnMenuItem('Názov', _showColumnName, (value) {
        setState(() => _showColumnName = value);
      }),
      _buildColumnMenuItem('Typ', _showColumnType, (value) {
        setState(() => _showColumnType = value);
      }),
      _buildColumnMenuItem('Kategória', _showColumnCategory, (value) {
        setState(() => _showColumnCategory = value);
      }),
      _buildColumnMenuItem('PLU', _showColumnPLU, (value) {
        setState(() => _showColumnPLU = value);
      }),
      _buildColumnMenuItem('EAN', _showColumnEAN, (value) {
        setState(() => _showColumnEAN = value);
      }),
      _buildColumnMenuItem('Nákup', _showColumnPurchase, (value) {
        setState(() => _showColumnPurchase = value);
      }),
      _buildColumnMenuItem('Predaj', _showColumnSale, (value) {
        setState(() => _showColumnSale = value);
      }),
      _buildColumnMenuItem('DPH', _showColumnVat, (value) {
        setState(() => _showColumnVat = value);
      }),
      _buildColumnMenuItem('Marža', _showColumnMargin, (value) {
        setState(() => _showColumnMargin = value);
      }),
      _buildColumnMenuItem(_showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH', _showColumnLastPurchasePrice, (value) {
        setState(() => _showColumnLastPurchasePrice = value);
      }),
      _buildColumnMenuItem('Stav', _showColumnStock, (value) {
        setState(() => _showColumnStock = value);
      }),
    ];
    
    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
  }
  
  void _showPrintDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PrintOptionsDialog(materials: _filteredMaterials),
    );
    
    if (result != null) {
      await _handlePrint(result);
    }
  }
  
  Future<void> _handlePrint(Map<String, dynamic> printConfig) async {
    try {
      // Show preview first
      await _showPrintPreview(printConfig);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba pri náhľade tlače: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _showPrintPreview(Map<String, dynamic> printConfig) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Príprava náhľadu...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Generate PDF for preview
    final pdf = await _generatePDFPreview(printConfig['columns'] as Map<String, dynamic>, printConfig['options'] as Map<String, dynamic>);
    
    // Hide loading indicator
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Show preview dialog
    await showDialog(
      context: context,
      builder: (context) => _PrintPreviewDialog(
        pdf: pdf,
        printConfig: printConfig,
        totalMaterials: _filteredMaterials.length,
        onPrint: (columns, options) => _generatePDF(columns, options),
      ),
    );
  }
  
  Future<pw.Font?> _loadUnicodeFont() async {
    try {
      // Load regular font from assets (primary source)
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('⚠ Failed to load font from assets: $e');
      // Fallback: try to download from CDN
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Regular.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          return pw.Font.ttf(response.bodyBytes.buffer.asByteData());
        }
      } catch (e2) {
        print('⚠ Failed to load font from CDN: $e2');
      }
    }
    return null;
  }
  
  Future<pw.Font?> _loadUnicodeBoldFont() async {
    try {
      // Load bold font from assets (primary source)
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('⚠ Failed to load bold font from assets: $e');
      // Fallback: try to download from CDN
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Bold.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          return pw.Font.ttf(response.bodyBytes.buffer.asByteData());
        }
      } catch (e2) {
        print('⚠ Failed to load bold font from CDN: $e2');
      }
    }
    return null;
  }
  
  Future<Uint8List> _generatePDFPreview(Map<String, dynamic> columns, Map<String, dynamic> options) async {
    final pdf = pw.Document();
    
    // Load Unicode fonts
    final unicodeFont = await _loadUnicodeFont();
    final unicodeBoldFont = await _loadUnicodeBoldFont();
    
    if (unicodeFont == null) {
      throw Exception('Nepodarilo sa načítať Unicode font pre tlač');
    }
    
    // Create table data
    final List<List<String>> tableData = [];
    
    // Add header row
    final List<String> header = [];
    if (columns['id'] == true) header.add('ID');
    if (columns['name'] == true) header.add('Názov');
    if (columns['type'] == true) header.add('Typ');
    if (columns['category'] == true) header.add('Kategória');
    if (columns['plu'] == true) header.add('PLU');
    if (columns['ean'] == true) header.add('EAN');
    if (columns['purchasePrice'] == true) header.add(_showPurchasePriceWithVat ? 'Nákupná cena s DPH' : 'Nákupná cena bez DPH');
    if (columns['lastPurchasePrice'] == true) header.add(_showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH');
    if (columns['salePrice'] == true) header.add(_showSalePriceWithVat ? 'Predajná cena s DPH' : 'Predajná cena bez DPH');
    if (columns['vat'] == true) header.add('DPH');
    if (columns['margin'] == true) header.add('Marža');
    if (columns['stock'] == true) header.add('Stav');
    tableData.add(header);
    
    // Add data rows (limit to first 10 for preview)
    final previewMaterials = _filteredMaterials.take(10).toList();
    for (final material in previewMaterials) {
      final row = <String>[];
      if (columns['id'] == true) row.add(material.warehouseNumber ?? material.id?.toString() ?? '-');
      if (columns['name'] == true) row.add(material.name);
      if (columns['type'] == true) row.add(_getMaterialTypeName(material.type));
      if (columns['category'] == true) row.add(_getCategoryName(material.category));
      if (columns['plu'] == true) row.add(material.pluCode ?? '-');
      if (columns['ean'] == true) row.add(material.eanCode ?? '-');
      if (columns['purchasePrice'] == true) {
        final price = _getPurchasePrice(material);
        row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
      }
      if (columns['lastPurchasePrice'] == true) {
        final lastMovement = material.id != null ? _lastPurchaseMovements[material.id!] : null;
        if (lastMovement != null) {
          final price = _showPurchasePriceWithVat ? lastMovement.purchasePriceWithVat : lastMovement.purchasePriceWithoutVat;
          row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
        } else {
          row.add('-');
        }
      }
      if (columns['salePrice'] == true) {
        final price = _getSalePrice(material);
        row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
      }
      if (columns['vat'] == true) {
        row.add(material.vatRate != null ? '${material.vatRate!.toStringAsFixed(1)}%' : '-');
      }
      if (columns['margin'] == true) {
        final margin = _getMarginPercentage(material);
        row.add(margin != null ? '${margin.toStringAsFixed(1)}%' : '-');
      }
      if (columns['stock'] == true) {
        row.add('${material.currentStock.toStringAsFixed(1)} ${material.unit}');
      }
      tableData.add(row);
    }
    
    // Add page to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (options['header'] == true) ...[
                pw.Text(
                  'PREHĽAD S KLADOVÝCH ZÁSOB (NÁHĽAD)',
                  style: pw.TextStyle(
                    font: unicodeBoldFont ?? unicodeFont,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Dátum: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Zobrazuje prvých ${previewMaterials.length} z ${_filteredMaterials.length} položiek',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
              
              // Table
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: unicodeBoldFont ?? unicodeFont,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 4,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellStyle: pw.TextStyle(
                  font: unicodeFont,
                  fontSize: 5,
                ),
                cellAlignments: {
                  for (int i = 0; i < header.length; i++)
                    i: pw.Alignment.centerLeft,
                  // Align numeric columns to right
                  if (columns['purchasePrice'] == true) header.indexOf(_showPurchasePriceWithVat ? 'Nákupná cena s DPH' : 'Nákupná cena bez DPH'): pw.Alignment.centerRight,
                  if (columns['lastPurchasePrice'] == true) header.indexOf(_showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH'): pw.Alignment.centerRight,
                  if (columns['salePrice'] == true) header.indexOf(_showSalePriceWithVat ? 'Predajná cena s DPH' : 'Predajná cena bez DPH'): pw.Alignment.centerRight,
                  if (columns['vat'] == true) header.indexOf('DPH'): pw.Alignment.centerRight,
                  if (columns['margin'] == true) header.indexOf('Marža'): pw.Alignment.centerRight,
                  if (columns['stock'] == true) header.indexOf('Stav'): pw.Alignment.centerRight,
                },
                columnWidths: {
                  for (int i = 0; i < header.length; i++)
                    i: const pw.FlexColumnWidth(),
                },
              ),
              
              if (options['footer'] == true) ...[
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Toto je len náhľad. Plný dokument bude obsahovať všetky ${_filteredMaterials.length} položiek.',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 7,
                    color: PdfColors.blue600,
                  ),
                ),
                pw.Text(
                  'Generované PWMS systémom',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  Future<void> _generatePDF(Map<String, dynamic> columns, Map<String, dynamic> options) async {
    final pdf = pw.Document();
    
    // Load Unicode fonts
    final unicodeFont = await _loadUnicodeFont();
    final unicodeBoldFont = await _loadUnicodeBoldFont();
    
    if (unicodeFont == null) {
      throw Exception('Nepodarilo sa načítať Unicode font pre tlač');
    }
    
    // Create table data
    final List<List<String>> tableData = [];
    
    // Add header row
    final List<String> header = [];
    if (columns['id'] == true) header.add('ID');
    if (columns['name'] == true) header.add('Názov');
    if (columns['type'] == true) header.add('Typ');
    if (columns['category'] == true) header.add('Kategória');
    if (columns['plu'] == true) header.add('PLU');
    if (columns['ean'] == true) header.add('EAN');
    if (columns['purchasePrice'] == true) header.add(_showPurchasePriceWithVat ? 'Nákupná cena s DPH' : 'Nákupná cena bez DPH');
    if (columns['lastPurchasePrice'] == true) header.add(_showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH');
    if (columns['salePrice'] == true) header.add(_showSalePriceWithVat ? 'Predajná cena s DPH' : 'Predajná cena bez DPH');
    if (columns['vat'] == true) header.add('DPH');
    if (columns['margin'] == true) header.add('Marža');
    if (columns['stock'] == true) header.add('Stav');
    tableData.add(header);
    
    // Add data rows
    for (final material in _filteredMaterials) {
      final row = <String>[];
      if (columns['id'] == true) row.add(material.warehouseNumber ?? material.id?.toString() ?? '-');
      if (columns['name'] == true) row.add(material.name);
      if (columns['type'] == true) row.add(_getMaterialTypeName(material.type));
      if (columns['category'] == true) row.add(_getCategoryName(material.category));
      if (columns['plu'] == true) row.add(material.pluCode ?? '-');
      if (columns['ean'] == true) row.add(material.eanCode ?? '-');
      if (columns['purchasePrice'] == true) {
        final price = _getPurchasePrice(material);
        row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
      }
      if (columns['lastPurchasePrice'] == true) {
        final lastMovement = material.id != null ? _lastPurchaseMovements[material.id!] : null;
        if (lastMovement != null) {
          final price = _showPurchasePriceWithVat ? lastMovement.purchasePriceWithVat : lastMovement.purchasePriceWithoutVat;
          row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
        } else {
          row.add('-');
        }
      }
      if (columns['salePrice'] == true) {
        final price = _getSalePrice(material);
        row.add(price != null ? '${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(price)}' : '-');
      }
      if (columns['vat'] == true) {
        row.add(material.vatRate != null ? '${material.vatRate!.toStringAsFixed(1)}%' : '-');
      }
      if (columns['margin'] == true) {
        final margin = _getMarginPercentage(material);
        row.add(margin != null ? '${margin.toStringAsFixed(1)}%' : '-');
      }
      if (columns['stock'] == true) {
        row.add('${material.currentStock.toStringAsFixed(1)} ${material.unit}');
      }
      tableData.add(row);
    }
    
    // Add page to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (options['header'] == true) ...[
                pw.Text(
                  'Prehľad skladových zásob',
                  style: pw.TextStyle(
                    font: unicodeBoldFont ?? unicodeFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Dátum: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Počet položiek: ${_filteredMaterials.length}',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
              
              // Table
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  font: unicodeBoldFont ?? unicodeFont,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 4,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellStyle: pw.TextStyle(
                  font: unicodeFont,
                  fontSize: 5,
                ),
                cellAlignments: {
                  for (int i = 0; i < header.length; i++)
                    i: pw.Alignment.centerLeft,
                  // Align numeric columns to right
                  if (columns['purchasePrice'] == true) header.indexOf(_showPurchasePriceWithVat ? 'Nákupná cena s DPH' : 'Nákupná cena bez DPH'): pw.Alignment.centerRight,
                  if (columns['lastPurchasePrice'] == true) header.indexOf(_showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH'): pw.Alignment.centerRight,
                  if (columns['salePrice'] == true) header.indexOf(_showSalePriceWithVat ? 'Predajná cena s DPH' : 'Predajná cena bez DPH'): pw.Alignment.centerRight,
                  if (columns['vat'] == true) header.indexOf('DPH'): pw.Alignment.centerRight,
                  if (columns['margin'] == true) header.indexOf('Marža'): pw.Alignment.centerRight,
                  if (columns['stock'] == true) header.indexOf('Stav'): pw.Alignment.centerRight,
                },
                columnWidths: {
                  for (int i = 0; i < header.length; i++)
                    i: const pw.FlexColumnWidth(),
                },
              ),
              
              if (options['footer'] == true) ...[
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generované PWMS systémom',
                  style: pw.TextStyle(
                    font: unicodeFont,
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
    
    // Save and print PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Skladove zasoby_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.pdf',
    );
  }

  PopupMenuItem<dynamic> _buildColumnMenuItem(String name, bool isVisible, ValueChanged<bool> onChanged) {
    return PopupMenuItem<dynamic>(
      child: Row(
        children: [
          Checkbox(
            value: isVisible,
            onChanged: (value) {
              Navigator.pop(context);
              onChanged(value ?? false);
            },
          ),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    if (_filteredMaterials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Žiadne položky',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        final isMedium = constraints.maxWidth > 700;
        
        if (isWide) {
          // Wide screen - full table
          return _buildFullTable();
        } else if (isMedium) {
          // Medium screen - responsive table with some columns hidden
          return _buildResponsiveTable();
        } else {
          // Narrow screen - compact table
          return _buildCompactTable();
        }
      },
    );
  }

  Widget _buildFullTable() {
    return Card(
      elevation: 2,
            shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                    ),
                  ),
                  child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                  if (_isBulkSelectionMode)
                    SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: _filteredMaterials.isNotEmpty && 
                            _filteredMaterials.where((m) => m.id != null && _selectedMaterials.contains(m.id)).length == _filteredMaterials.length,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedMaterials = _filteredMaterials
                                  .where((m) => m.id != null)
                                  .map((m) => m.id!)
                                  .toSet();
                            } else {
                              _selectedMaterials.clear();
                            }
                          });
                        },
                      ),
                    ),
                  if (_showColumnId)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('ID', sortColumn: 'id'),
                    ),
                  if (_showColumnName)
                        Expanded(
                          flex: 3,
                      child: _buildHeaderCellWithContextMenu('Názov', sortColumn: 'name'),
                    ),
                  if (_showColumnType)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('Typ', sortColumn: 'type'),
                    ),
                  if (_showColumnCategory)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('Kategória', sortColumn: 'category'),
                    ),
                  if (_showColumnPLU)
                        Expanded(
                          flex: 2,
                      child: _buildHeaderCellWithContextMenu('PLU', sortColumn: 'plu'),
                    ),
                  if (_showColumnEAN)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('EAN', sortColumn: 'ean'),
                    ),
                  if (_showColumnPurchase)
                        Expanded(
                          flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                          });
                        },
                        onLongPress: () => _handleSort('purchase'),
                        onSecondaryTap: () => _showColumnContextMenu(context, 'Nákup'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _showPurchasePriceWithVat ? 'Nákup s DPH (klik = prepnúť, podržať = zoradiť)' : 'Nákup bez DPH (klik = prepnúť, podržať = zoradiť)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showPurchasePriceWithVat ? Colors.blue.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_sortColumn == 'purchase') ...[
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                          child: Text(
                                      _getPriceLabel(true),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                        height: 1.1,
                            ),
                          ),
                        ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 12,
                                    color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showColumnSale)
                        Expanded(
                          flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSalePriceWithVat = !_showSalePriceWithVat;
                          });
                        },
                        onLongPress: () => _handleSort('sale'),
                        onSecondaryTap: () => _showColumnContextMenu(context, 'Predaj'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _showSalePriceWithVat ? 'Predaj s DPH (klik = prepnúť, podržať = zoradiť)' : 'Predaj bez DPH (klik = prepnúť, podržať = zoradiť)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showSalePriceWithVat ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_sortColumn == 'sale') ...[
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                          child: Text(
                                      _getPriceLabel(false),
                            textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700,
                                        height: 1.1,
                            ),
                          ),
                        ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 12,
                                    color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showColumnVat)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('DPH', textAlign: TextAlign.right),
                    ),
                  if (_showColumnMargin)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('Marža', textAlign: TextAlign.right, sortColumn: 'margin'),
                    ),
                  if (_showColumnLastPurchasePrice)
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                          });
                        },
                        onSecondaryTap: () => _showColumnContextMenu(context, _showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _showPurchasePriceWithVat ? 'Posl. nákup s DPH (klik = prepnúť)' : 'Posl. nákup bez DPH (klik = prepnúť)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showPurchasePriceWithVat ? Colors.blue.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 12,
                                    color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showColumnStock)
                    Expanded(
                      flex: 2,
                      child: _buildHeaderCellWithContextMenu('Stav', textAlign: TextAlign.right, sortColumn: 'stock'),
                    ),
                      ],
                    ),
                  ),
                ),
                // Table rows
                ..._filteredMaterials.asMap().entries.map((entry) {
                  final index = entry.key;
                  final material = entry.value;
                  final isLowStock = material.currentStock <= material.minStock;
                  
                  return InkWell(
                    onTap: () {
                      if (_isBulkSelectionMode && material.id != null) {
                        setState(() {
                          if (_selectedMaterials.contains(material.id!)) {
                            _selectedMaterials.remove(material.id!);
                          } else {
                            _selectedMaterials.add(material.id!);
                          }
                        });
                      } else {
                        _showMaterialQuickActions(material);
                      }
                    },
                      child: Container(
                        decoration: BoxDecoration(
                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: index < _filteredMaterials.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                        if (_isBulkSelectionMode)
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: material.id != null && _selectedMaterials.contains(material.id),
                              onChanged: (value) {
                                setState(() {
                                  if (material.id != null) {
                                    if (value == true) {
                                      _selectedMaterials.add(material.id!);
                                    } else {
                                      _selectedMaterials.remove(material.id!);
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        if (_showColumnId)
                          Expanded(
                            flex: 2,
                            child: Text(
                              material.warehouseNumber ?? (material.id != null ? material.id.toString() : '-'),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: material.warehouseNumber != null ? Colors.blue.shade700 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (_showColumnName)
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  material.hasRecyclingFee && material.recyclingFee != null
                                      ? MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: Tooltip(
                                            message: 'Recyklačný poplatok: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.recyclingFee)}',
                                            child: Icon(
                                              Icons.recycling,
                                              size: 22,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                              if (material.hasRecyclingFee && material.recyclingFee != null)
                                const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => PriceHistoryScreen(material: material),
                                                    ),
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        material.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w500,
                                                          fontSize: 14,
                                                          color: Colors.blue.shade700,
                                                          decoration: TextDecoration.underline,
                                                          decorationColor: Colors.blue.shade700,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.history,
                                                      size: 14,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                                tooltip: 'Možnosti',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (value) => _handleMenuAction(value, material),
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                                        const SizedBox(width: 12),
                                        const Text('Upraviť'),
                                ],
                              ),
                            ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 12),
                                        const Text('Vymazať'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                                ],
                              ),
                            ),
                      if (_showColumnType)
                            Expanded(
                              flex: 2,
                              child: Text(
                                _getMaterialTypeName(material.type),
                                style: TextStyle(
                                  fontSize: 13,
                              color: Colors.grey[700],
                                ),
                            overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      if (_showColumnCategory)
                            Expanded(
                              flex: 2,
                              child: Text(
                                _getCategoryName(material.category),
                                style: TextStyle(
                                  fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_showColumnPLU)
                        Expanded(
                          flex: 2,
                          child: Text(
                            material.pluCode ?? '-',
                            style: TextStyle(
                              fontSize: 12,
                                  color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_showColumnEAN)
                        Expanded(
                          flex: 2,
                          child: Text(
                            material.eanCode ?? '-',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_showColumnPurchase)
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                              });
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                '${_formatPurchasePrice(_getPurchasePrice(material))} €',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      if (_showColumnSale)
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showSalePriceWithVat = !_showSalePriceWithVat;
                              });
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                '${_formatSalePrice(_getSalePrice(material))} €',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      if (_showColumnVat)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (material.vatRate != null)
                                Text(
                                  '${material.vatRate!.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Text(
                                  '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (_getVatAmount(material) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    NumberFormat.currency(symbol: '€', decimalDigits: 2).format(
                                      _getVatAmount(material)!
                                    ),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade600,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      if (_showColumnMargin)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_getMarginPercentage(material) != null)
                                Text(
                                  '${_getMarginPercentage(material)!.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Text(
                                  '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (_getMarginAmount(material) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    NumberFormat.currency(symbol: '€', decimalDigits: 2).format(
                                      _getMarginAmount(material)!
                                    ),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getMarginAmount(material)! >= 0 
                                          ? Colors.purple.shade600 
                                          : Colors.red.shade600,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      if (_showColumnLastPurchasePrice)
                        Expanded(
                          flex: 2,
                          child: _buildLastPurchasePriceCell(material),
                        ),
                      if (_showColumnStock)
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${material.currentStock.toStringAsFixed(1)} ${material.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                          color: isLowStock
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      if (isLowStock)
                                        Text(
                                          'Min: ${material.minStock.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (isLowStock) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.warning,
                                      color: Colors.red.shade700,
                                  size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildResponsiveTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_showColumnId)
                    Expanded(flex: 2, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  Expanded(flex: 3, child: Text('Názov', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  Expanded(flex: 2, child: Text('Typ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  Expanded(flex: 2, child: Text('Kategória', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _showPurchasePriceWithVat ? 'Nákup s DPH' : 'Nákup bez DPH',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showPurchasePriceWithVat ? Colors.blue.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _getPriceLabel(true),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.swap_horiz, size: 12, color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700),
                                ],
                              ),
                            ),
                          ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showSalePriceWithVat = !_showSalePriceWithVat;
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Tooltip(
                          message: _showSalePriceWithVat ? 'Predaj s DPH' : 'Predaj bez DPH',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: _showSalePriceWithVat ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _getPriceLabel(false),
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.visible,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.swap_horiz, size: 12, color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showColumnVat)
                    Expanded(flex: 2, child: Text('DPH', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  if (_showColumnMargin)
                    Expanded(flex: 2, child: Text('Marža', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                  if (_showColumnLastPurchasePrice)
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                          });
                        },
                        onSecondaryTap: () => _showColumnContextMenu(context, _showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH'),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: _showPurchasePriceWithVat ? 'Posl. nákup s DPH (klik = prepnúť)' : 'Posl. nákup bez DPH (klik = prepnúť)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showPurchasePriceWithVat ? Colors.blue.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _showPurchasePriceWithVat ? 'Posl. nákup s DPH' : 'Posl. nákup bez DPH',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 10,
                                    color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(flex: 2, child: Text('Stav', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]))),
                ],
              ),
            ),
          ),
          ..._filteredMaterials.asMap().entries.map((entry) {
            final index = entry.key;
            final material = entry.value;
            final isLowStock = material.currentStock <= material.minStock;
            
            return InkWell(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: index < _filteredMaterials.length - 1 ? 1 : 0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      if (_showColumnId)
                        Expanded(
                          flex: 2,
                          child: Text(
                            material.warehouseNumber ?? (material.id != null ? material.id.toString() : '-'),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: material.warehouseNumber != null ? Colors.blue.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            material.hasRecyclingFee && material.recyclingFee != null
                                ? MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Tooltip(
                                      message: 'Recyklačný poplatok: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.recyclingFee)}',
                                      child: Icon(
                                        Icons.recycling,
                                        size: 20,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            if (material.hasRecyclingFee && material.recyclingFee != null)
                              const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PriceHistoryScreen(material: material),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                material.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: Colors.blue.shade700,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: Colors.blue.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.history,
                                              size: 14,
                                              color: Colors.blue.shade700,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (material.pluCode != null || material.eanCode != null)
                                    Text(
                                      '${material.pluCode ?? ''} ${material.eanCode ?? ''}'.trim(),
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                              tooltip: 'Možnosti',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (value) => _handleMenuAction(value, material),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                                      const SizedBox(width: 12),
                                      const Text('Upraviť'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 12),
                                      const Text('Vymazať'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(_getMaterialTypeName(material.type), style: TextStyle(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text(_getCategoryName(material.category), style: TextStyle(fontSize: 13, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPurchasePriceWithVat = !_showPurchasePriceWithVat;
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              _getPurchasePrice(material) != null ? NumberFormat.currency(symbol: '€', decimalDigits: 2).format(_getPurchasePrice(material)!) : '-',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSalePriceWithVat = !_showSalePriceWithVat;
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              '${_formatSalePrice(_getSalePrice(material))} €',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, color: _showSalePriceWithVat ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (_showColumnVat)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (material.vatRate != null)
                                Text(
                                  '${material.vatRate!.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                                )
                              else
                                Text(
                                  '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              if (_getVatAmount(material) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    NumberFormat.currency(symbol: '€', decimalDigits: 2).format(
                                      _getVatAmount(material)!
                                    ),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                                  ),
                                )
                              else
                                const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      if (_showColumnMargin)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_getMarginPercentage(material) != null)
                                Text(
                                  '${_getMarginPercentage(material)!.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13, color: Colors.purple.shade700, fontWeight: FontWeight.w600),
                                )
                              else
                                Text(
                                  '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              if (_getMarginAmount(material) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    NumberFormat.currency(symbol: '€', decimalDigits: 2).format(
                                      _getMarginAmount(material)!
                                    ),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getMarginAmount(material)! >= 0 
                                          ? Colors.purple.shade600 
                                          : Colors.red.shade600,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      if (_showColumnLastPurchasePrice)
                        Expanded(
                          flex: 2,
                          child: _buildLastPurchasePriceCell(material),
                        ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${material.currentStock.toStringAsFixed(1)} ${material.unit}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isLowStock ? Colors.red.shade700 : Colors.green.shade700)),
                                if (isLowStock) Text('Min: ${material.minStock.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                              ],
                            ),
                            if (isLowStock) ...[const SizedBox(width: 8), Icon(Icons.warning, color: Colors.red.shade700, size: 18)],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactTable() {
    return Column(
      children: _filteredMaterials.map((material) {
        final isLowStock = material.currentStock <= material.minStock;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isLowStock ? Colors.red.shade300 : Colors.grey.shade300,
              width: isLowStock ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getMaterialIcon(material.type).icon, color: _getMaterialColor(material.type), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PriceHistoryScreen(material: material),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        material.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.blue.shade700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.history,
                                        size: 14,
                                        color: Colors.blue.shade700,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text(_getMaterialTypeName(material.type), style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                  child: Text(_getCategoryName(material.category), style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isLowStock) Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem('Stav', '${material.currentStock.toStringAsFixed(1)} ${material.unit}', isLowStock ? Colors.red.shade700 : Colors.green.shade700),
                      ),
                      if (_showColumnLastPurchasePrice)
                        Expanded(
                          child: _buildLastPurchasePriceCompactItem(material),
                        ),
                      if (material.averagePurchasePriceWithVat != null)
                        Expanded(
                          child: _buildInfoItem('Nákup', '${_formatPurchasePrice(material.averagePurchasePriceWithVat)} €', Colors.blue.shade700),
                        ),
                      if (material.salePrice != null)
                        Expanded(
                          child: _buildInfoItem('Predaj', '${_formatSalePrice(material.salePrice)} €', Colors.green.shade700),
                        ),
                    ],
                  ),
                  if (material.pluCode != null || material.eanCode != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (material.pluCode != null)
                          Expanded(
                            child: _buildInfoItem('PLU', material.pluCode!, Colors.grey[700]!, isMonospace: true),
                          ),
                        if (material.eanCode != null)
                          Expanded(
                            child: _buildInfoItem('EAN', material.eanCode!, Colors.grey[700]!, isMonospace: true),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoItem(String label, String value, Color valueColor, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor,
            fontWeight: FontWeight.w600,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLastPurchasePriceCompactItem(Material material) {
    final lastMovement = material.id != null ? _lastPurchaseMovements[material.id!] : null;
    
    if (lastMovement == null) {
      return _buildInfoItem('Posl. nákup s DPH', '-', Colors.grey);
    }
    
    // Use price with VAT if available, otherwise without VAT
    final price = _showPurchasePriceWithVat 
        ? lastMovement.purchasePriceWithVat 
        : lastMovement.purchasePriceWithoutVat;
    
    if (price == null) {
      return _buildInfoItem('Posl. nákup s DPH', '-', Colors.grey);
    }
    
    return _buildInfoItem(
      'Posl. nákup s DPH', 
      '${_formatPurchasePrice(price)} €', 
      _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700
    );
  }

  Widget _buildCardView() {
    if (_filteredMaterials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Žiadne položky',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _filteredMaterials.length,
      itemBuilder: (context, index) {
        final material = _filteredMaterials[index];
        final isLowStock = material.currentStock <= material.minStock;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLowStock ? Colors.red.shade300 : Colors.grey.shade300,
              width: isLowStock ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              // TODO: Navigate to material detail
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and name
                  Row(
                    children: [
                      if (material.hasRecyclingFee && material.recyclingFee != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Tooltip(
                              message: 'Recyklačný poplatok: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.recyclingFee)}',
                              child: Icon(
                                Icons.recycling,
                                size: 24,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ),
                      if (material.hasRecyclingFee && material.recyclingFee != null)
                        const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                        Row(
                                          children: [
                                            Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PriceHistoryScreen(material: material),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            material.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.blue.shade700,
                                              decoration: TextDecoration.underline,
                                              decorationColor: Colors.blue.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.history,
                                          size: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _getMaterialTypeName(material.type),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                        tooltip: 'Možnosti',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) => _handleMenuAction(value, material),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 12),
                                const Text('Upraviť'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 12),
                                const Text('Vymazať'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isLowStock)
                        Icon(
                          Icons.warning,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getCategoryName(material.category),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Stock status
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLowStock 
                          ? Colors.red.shade50 
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stav',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${material.currentStock.toStringAsFixed(1)} ${material.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isLowStock
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            if (isLowStock)
                              Text(
                                'Min: ${material.minStock.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Codes and prices
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (material.pluCode != null) ...[
                              Text(
                                'PLU',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                material.pluCode!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (material.eanCode != null) ...[
                              Text(
                                'EAN',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                material.eanCode!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Prices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (material.averagePurchasePriceWithVat != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nákup',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                Text(
                                  '${_formatPurchasePrice(material.averagePurchasePriceWithVat)} €',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (material.averagePurchasePriceWithVat != null && material.salePrice != null)
                        const SizedBox(width: 6),
                      if (material.salePrice != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Predaj',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(symbol: '€', decimalDigits: 2)
                                      .format(material.salePrice),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildLastPurchasePriceCell(Material material) {
    final lastMovement = material.id != null ? _lastPurchaseMovements[material.id!] : null;
    
    if (lastMovement == null) {
      return const Text(
        '-',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    
    // Use price with VAT if available, otherwise without VAT
    final price = _showPurchasePriceWithVat 
        ? lastMovement.purchasePriceWithVat 
        : lastMovement.purchasePriceWithoutVat;
    
    if (price == null) {
      return const Text(
        '-',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatPurchasePrice(price)} €',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            color: _showPurchasePriceWithVat ? Colors.blue.shade700 : Colors.red.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (lastMovement.movementDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _formatDate(lastMovement.movementDate),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatisticsChartsDialog extends StatelessWidget {
  final List<Material> materials;
  
  const _StatisticsChartsDialog({required this.materials});
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.2,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(1),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grafy a štatistiky',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Kategórie'),
                        Tab(text: 'Top 10'),
                        Tab(text: 'Hodnota'),
                        Tab(text: 'Trendy'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCategoryPieChart(),
                          _buildTop10BarChart(),
                          _buildValueChart(),
                          _buildTrendsChart(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryPieChart() {
    final categoryData = <String, double>{};
    for (final material in materials) {
      final price = material.averagePurchasePriceWithVat ?? 0.0;
      final value = material.currentStock * price;
      categoryData[material.category] = (categoryData[material.category] ?? 0) + value;
    }
    
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    int colorIndex = 0;
    
    if (categoryData.isEmpty) {
      return const Center(child: Text('Žiadne dáta'));
    }
    
    final total = categoryData.values.fold(0.0, (a, b) => a + b);
    
    return PieChart(
      PieChartData(
        sections: categoryData.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          return PieChartSectionData(
            value: entry.value,
            title: '${(entry.value / total * 100).toStringAsFixed(1)}%',
            color: color,
            radius: 100,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
  
  Widget _buildTop10BarChart() {
    final sorted = List<Material>.from(materials);
    sorted.sort((a, b) {
      final valueA = (a.averagePurchasePriceWithVat ?? 0.0) * a.currentStock;
      final valueB = (b.averagePurchasePriceWithVat ?? 0.0) * b.currentStock;
      return valueB.compareTo(valueA);
    });
    final top10 = sorted.take(10).toList();
    
    if (top10.isEmpty) {
      return const Center(child: Text('Žiadne dáta'));
    }
    
    final maxValue = top10.map((m) => (m.averagePurchasePriceWithVat ?? 0.0) * m.currentStock).reduce((a, b) => a > b ? a : b);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.grey[800]!,
            tooltipRoundedRadius: 8,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < top10.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      top10[value.toInt()].name.length > 10
                          ? '${top10[value.toInt()].name.substring(0, 10)}...'
                          : top10[value.toInt()].name,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}k',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: top10.asMap().entries.map((entry) {
          final index = entry.key;
          final material = entry.value;
          final value = (material.averagePurchasePriceWithVat ?? 0.0) * material.currentStock;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: Colors.blue,
                width: 20,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildValueChart() {
    final totalValue = materials.fold<double>(0, (sum, m) {
      return sum + ((m.averagePurchasePriceWithVat ?? 0.0) * m.currentStock);
    });
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Celková hodnota skladu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat.currency(symbol: '€', decimalDigits: 2).format(totalValue),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrendsChart() {
    // Simplified - would need historical data from stock_movements
    return const Center(
      child: Text('Trendy zásob vyžadujú historické dáta'),
    );
  }
}

class _PrintOptionsDialog extends StatefulWidget {
  final List<Material> materials;
  
  const _PrintOptionsDialog({required this.materials});
  
  @override
  State<_PrintOptionsDialog> createState() => _PrintOptionsDialogState();
}

class _PrintOptionsDialogState extends State<_PrintOptionsDialog> {
  // Column selection options
  bool _printId = true;
  bool _printName = true;
  bool _printType = true;
  bool _printCategory = true;
  bool _printPLU = false;
  bool _printEAN = false;
  bool _printPurchasePrice = true;
  bool _printLastPurchasePrice = true;
  bool _printSalePrice = true;
  bool _printVat = true;
  bool _printMargin = true;
  bool _printStock = true;
  
  // Print options
  String _printFormat = 'pdf'; // 'pdf' or 'paper'
  bool _printHeader = true;
  bool _printFooter = true;
  bool _printDate = true;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.print, size: 28, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  'Tlač zásob',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Print format selection
            Text(
              'Formát tlače',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('PDF'),
                    value: 'pdf',
                    groupValue: _printFormat,
                    onChanged: (value) => setState(() => _printFormat = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Papier'),
                    value: 'paper',
                    groupValue: _printFormat,
                    onChanged: (value) => setState(() => _printFormat = value!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Column selection
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stĺpce na tlač',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Basic columns
                    _buildSectionHeader('Základné informácie'),
                    CheckboxListTile(
                      title: const Text('ID'),
                      value: _printId,
                      onChanged: (value) => setState(() => _printId = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Názov'),
                      value: _printName,
                      onChanged: (value) => setState(() => _printName = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Typ'),
                      value: _printType,
                      onChanged: (value) => setState(() => _printType = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Kategória'),
                      value: _printCategory,
                      onChanged: (value) => setState(() => _printCategory = value!),
                    ),
                    
                    _buildSectionHeader('Kódy'),
                    CheckboxListTile(
                      title: const Text('PLU kód'),
                      value: _printPLU,
                      onChanged: (value) => setState(() => _printPLU = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('EAN kód'),
                      value: _printEAN,
                      onChanged: (value) => setState(() => _printEAN = value!),
                    ),
                    
                    _buildSectionHeader('Ceny'),
                    CheckboxListTile(
                      title: const Text('Nákupná cena'),
                      value: _printPurchasePrice,
                      onChanged: (value) => setState(() => _printPurchasePrice = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Posledná nákupná cena'),
                      value: _printLastPurchasePrice,
                      onChanged: (value) => setState(() => _printLastPurchasePrice = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Predajná cena'),
                      value: _printSalePrice,
                      onChanged: (value) => setState(() => _printSalePrice = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('DPH'),
                      value: _printVat,
                      onChanged: (value) => setState(() => _printVat = value!),
                    ),
                    CheckboxListTile(
                      title: const Text('Marža'),
                      value: _printMargin,
                      onChanged: (value) => setState(() => _printMargin = value!),
                    ),
                    
                    _buildSectionHeader('Sklad'),
                    CheckboxListTile(
                      title: const Text('Stav zásob'),
                      value: _printStock,
                      onChanged: (value) => setState(() => _printStock = value!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Print options
            Text(
              'Ďalšie možnosti',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Záhlavie (názov a dátum)'),
              value: _printHeader,
              onChanged: (value) => setState(() => _printHeader = value!),
            ),
            CheckboxListTile(
              title: const Text('Pätička (počet položiek a súhrn)'),
              value: _printFooter,
              onChanged: (value) => setState(() => _printFooter = value!),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Zrušiť'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePrint(),
                    icon: const Icon(Icons.print),
                    label: const Text('Tlačiť'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
  
  void _handlePrint() {
    // Create print configuration
    final printConfig = {
      'format': _printFormat,
      'columns': {
        'id': _printId,
        'name': _printName,
        'type': _printType,
        'category': _printCategory,
        'plu': _printPLU,
        'ean': _printEAN,
        'purchasePrice': _printPurchasePrice,
        'lastPurchasePrice': _printLastPurchasePrice,
        'salePrice': _printSalePrice,
        'vat': _printVat,
        'margin': _printMargin,
        'stock': _printStock,
      },
      'options': {
        'header': _printHeader,
        'footer': _printFooter,
        'date': _printDate,
      },
    };
    
    Navigator.of(context).pop(printConfig);
  }
}

class _PrintPreviewDialog extends StatefulWidget {
  final Uint8List pdf;
  final Map<String, dynamic> printConfig;
  final int totalMaterials;
  final Future<void> Function(Map<String, dynamic>, Map<String, dynamic>) onPrint;
  
  const _PrintPreviewDialog({
    required this.pdf,
    required this.printConfig,
    required this.totalMaterials,
    required this.onPrint,
  });
  
  @override
  State<_PrintPreviewDialog> createState() => _PrintPreviewDialogState();
}

class _PrintPreviewDialogState extends State<_PrintPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.preview, size: 28, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  'Náhľad tlače',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Preview area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PdfPreview(
                    build: (format) => widget.pdf,
                    allowSharing: false,
                    allowPrinting: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    maxPageWidth: 700,
                    pdfPreviewPageDecoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    initialPageFormat: PdfPageFormat.a4,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toto je náhľad prvých 10 položiek. Plný dokument bude obsahovať všetkých ${widget.totalMaterials} položiek.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Späť k úpravám'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _executePrint(),
                    icon: const Icon(Icons.print),
                    label: const Text('Tlačiť všetko'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _executePrint() async {
    Navigator.of(context).pop();
    
    try {
      final columns = widget.printConfig['columns'] as Map<String, dynamic>;
      final options = widget.printConfig['options'] as Map<String, dynamic>;
      
      await widget.onPrint(columns, options);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF bolo vygenerované'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba pri tlači: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _MaterialDetailPanel extends StatelessWidget {
  final Material material;
  final ScrollController scrollController;
  
  const _MaterialDetailPanel({
    required this.material,
    required this.scrollController,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  material.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildDetailCard(
                  'Základné informácie',
                  [
                    _buildDetailRow('Názov', material.name),
                    _buildDetailRow('Typ', material.type),
                    _buildDetailRow('Kategória', material.category),
                    _buildDetailRow('Jednotka', material.unit),
                    if (material.pluCode != null)
                      _buildDetailRow('PLU', material.pluCode!),
                    if (material.eanCode != null)
                      _buildDetailRow('EAN', material.eanCode!),
                    if (material.warehouseNumber != null)
                      _buildDetailRow('Skladové číslo', material.warehouseNumber!),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  'Zásoby',
                  [
                    _buildDetailRow('Aktuálny stav', '${material.currentStock.toStringAsFixed(1)} ${material.unit}'),
                    _buildDetailRow('Minimálny stav', '${material.minStock.toStringAsFixed(1)} ${material.unit}'),
                    _buildDetailRow('Rozdiel', '${(material.currentStock - material.minStock).toStringAsFixed(1)} ${material.unit}'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  'Ceny',
                  [
                    if (material.averagePurchasePriceWithVat != null)
                      _buildDetailRow('Nákupná cena (s DPH)', NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.averagePurchasePriceWithVat)),
                    if (material.salePrice != null)
                      _buildDetailRow('Predajná cena', NumberFormat.currency(symbol: '€', decimalDigits: 2).format(material.salePrice)),
                    if (material.vatRate != null)
                      _buildDetailRow('DPH sadzba', '${material.vatRate!.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  'Dátumy',
                  [
                    _buildDetailRow('Vytvorené', DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(material.createdAt))),
                    _buildDetailRow('Posledná zmena', DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(material.updatedAt))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}