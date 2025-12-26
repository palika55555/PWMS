import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/auto_order.dart';
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';

class AutoOrdersScreen extends StatefulWidget {
  const AutoOrdersScreen({super.key});

  @override
  State<AutoOrdersScreen> createState() => _AutoOrdersScreenState();
}

class _AutoOrdersScreenState extends State<AutoOrdersScreen> {
  List<AutoOrder> _orders = [];
  Map<int, material_model.Material> _materials = {};
  Map<int, Supplier> _suppliers = {};
  bool _loading = true;
  String _filterStatus = 'all'; // all, pending, approved, rejected, ordered

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final orders = await dbProvider.getAutoOrders(
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    final materials = await dbProvider.getMaterials();
    final suppliers = await dbProvider.getSuppliers();
    
    final materialsMap = <int, material_model.Material>{};
    for (final m in materials) {
      if (m.id != null) {
        materialsMap[m.id!] = m;
      }
    }
    
    final suppliersMap = <int, Supplier>{};
    for (final s in suppliers) {
      if (s.id != null) {
        suppliersMap[s.id!] = s;
      }
    }
    
    setState(() {
      _orders = orders;
      _materials = materialsMap;
      _suppliers = suppliersMap;
      _loading = false;
    });
  }

  Future<void> _generateOrders() async {
    setState(() => _loading = true);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await dbProvider.generateAutoOrders();
    await _loadData();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Automatické objednávky boli vygenerované'),
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
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await dbProvider.updateAutoOrderStatus(orderId, status);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatické objednávky'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateOrders,
            tooltip: 'Vygenerovať objednávky',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Všetky'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Čakajúce'),
                  const SizedBox(width: 8),
                  _buildFilterChip('approved', 'Schválené'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ordered', 'Objednané'),
                ],
              ),
            ),
          ),
          
          // Orders list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Žiadne objednávky',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _generateOrders,
                              icon: const Icon(Icons.add),
                              label: const Text('Vygenerovať objednávky'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final material = _materials[order.materialId];
                            final supplier = _suppliers[order.supplierId];
                            
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                            material?.name ?? 'Neznámy materiál',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            _getStatusText(order.status),
                                            style: TextStyle(
                                              color: _getStatusColor(order.status),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (supplier != null) ...[
                                      Row(
                                        children: [
                                          Icon(Icons.business, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            supplier.name,
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Aktuálny stav',
                                            '${order.currentStock.toStringAsFixed(1)}',
                                            Icons.inventory,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Min. stav',
                                            '${order.minStock.toStringAsFixed(1)}',
                                            Icons.warning,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildInfoItem(
                                            'Navrhované',
                                            '${order.suggestedQuantity.toStringAsFixed(1)}',
                                            Icons.shopping_cart,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (order.status == 'pending')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _updateOrderStatus(order.id!, 'approved'),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Schváliť'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.green,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _updateOrderStatus(order.id!, 'rejected'),
                                              icon: const Icon(Icons.close),
                                              label: const Text('Zamietnuť'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (order.status == 'approved')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateOrderStatus(order.id!, 'ordered'),
                                          icon: const Icon(Icons.check_circle),
                                          label: const Text('Označiť ako objednané'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _loadData();
        });
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey[900],
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'ordered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Čaká';
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      case 'ordered':
        return 'Objednané';
      default:
        return status;
    }
  }
}


