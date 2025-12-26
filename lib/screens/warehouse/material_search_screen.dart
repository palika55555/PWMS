import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/material.dart' as material_model;
import 'create_material_screen.dart';
import 'price_history_screen.dart';

class MaterialSearchScreen extends StatefulWidget {
  const MaterialSearchScreen({super.key});

  @override
  State<MaterialSearchScreen> createState() => _MaterialSearchScreenState();
}

class _MaterialSearchScreenState extends State<MaterialSearchScreen> {
  final _searchController = TextEditingController();
  List<material_model.Material> _allMaterials = [];
  List<material_model.Material> _filteredMaterials = [];
  String? _selectedCategory;
  String? _selectedType;
  bool _showLowStockOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _searchController.addListener(_filterMaterials);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    setState(() {
      _allMaterials = materials;
      _filteredMaterials = materials;
      _loading = false;
    });
    _filterMaterials();
  }

  void _filterMaterials() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaterials = _allMaterials.where((material) {
        final matchesSearch = query.isEmpty ||
            material.name.toLowerCase().contains(query) ||
            material.pluCode?.toLowerCase().contains(query) == true ||
            material.eanCode?.toLowerCase().contains(query) == true ||
            material.type.toLowerCase().contains(query);
        
        final matchesCategory = _selectedCategory == null || material.category == _selectedCategory;
        final matchesType = _selectedType == null || material.type == _selectedType;
        final matchesLowStock = !_showLowStockOnly || material.currentStock <= material.minStock;
        
        return matchesSearch && matchesCategory && matchesType && matchesLowStock;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyhľadávanie materiálov'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // TODO: Open QR scanner
            },
            tooltip: 'Skenovať QR kód',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Hľadať podľa názvu, PLU, EAN...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                // Filters
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Nízky stav'),
                        selected: _showLowStockOnly,
                        onSelected: (selected) {
                          setState(() {
                            _showLowStockOnly = selected;
                            _filterMaterials();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategória',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Všetky')),
                          const DropdownMenuItem(value: 'warehouse', child: Text('Sklad')),
                          const DropdownMenuItem(value: 'production', child: Text('Výroba')),
                          const DropdownMenuItem(value: 'retail', child: Text('Maloobchod')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _filterMaterials();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Typ',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Všetky')),
                          const DropdownMenuItem(value: 'cement', child: Text('Cement')),
                          const DropdownMenuItem(value: 'aggregate', child: Text('Štrk')),
                          const DropdownMenuItem(value: 'water', child: Text('Voda')),
                          const DropdownMenuItem(value: 'plasticizer', child: Text('Plastifikátor')),
                          const DropdownMenuItem(value: 'other', child: Text('Iné')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                            _filterMaterials();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMaterials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Žiadne výsledky',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          final isLowStock = material.currentStock <= material.minStock;
                          
                          return Card(
                            elevation: isLowStock ? 4 : 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isLowStock
                                  ? BorderSide(color: Colors.orange.shade300, width: 2)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getMaterialColor(material.type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getMaterialIcon(material.type),
                                      color: _getMaterialColor(material.type),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
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
                                                              fontSize: 16,
                                                              color: Colors.blue.shade700,
                                                              decoration: TextDecoration.underline,
                                                              decorationColor: Colors.blue.shade700,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Icon(
                                                            Icons.history,
                                                            size: 16,
                                                            color: Colors.blue.shade700,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (material.warehouseNumber != null && material.warehouseNumber!.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(
                                                          'Č. skladu: ${material.warehouseNumber}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey.shade600,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (isLowStock)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'Nízky stav',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.orange.shade900,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_getMaterialTypeName(material.type)} • ${material.category}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (material.pluCode != null || material.eanCode != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (material.pluCode != null) ...[
                                                  Icon(Icons.qr_code, size: 12, color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'PLU: ${material.pluCode}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                                if (material.pluCode != null && material.eanCode != null)
                                                  Text(' • ', style: TextStyle(color: Colors.grey[600])),
                                                if (material.eanCode != null)
                                                  Text(
                                                    'EAN: ${material.eanCode}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Stav: ${material.currentStock.toStringAsFixed(1)} ${material.unit}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: isLowStock
                                                            ? Colors.orange.shade900
                                                            : Colors.green.shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Min: ${material.minStock.toStringAsFixed(1)} ${material.unit}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (material.averagePurchasePriceWithVat != null)
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${material.averagePurchasePriceWithVat!.toStringAsFixed(2)} €',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      'za ${material.unit}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
      ),
    );
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

  IconData _getMaterialIcon(String type) {
    switch (type) {
      case 'cement':
        return Icons.circle;
      case 'aggregate':
        return Icons.grain;
      case 'water':
        return Icons.water_drop;
      case 'plasticizer':
        return Icons.science;
      default:
        return Icons.inventory_2;
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
}




