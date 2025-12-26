import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/warehouse.dart';
import 'create_warehouse_screen.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<Warehouse> _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final warehouses = await dbProvider.getWarehouses();
    setState(() {
      _warehouses = warehouses;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sklady'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateWarehouseScreen(),
                ),
              );
              if (result == true) {
                _loadWarehouses();
              }
            },
            tooltip: 'Nový sklad',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _warehouses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadne sklady',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateWarehouseScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadWarehouses();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Pridať prvý sklad'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWarehouses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _warehouses.length,
                    itemBuilder: (context, index) {
                      final warehouse = _warehouses[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateWarehouseScreen(warehouse: warehouse),
                              ),
                            );
                            if (result == true) {
                              _loadWarehouses();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: warehouse.isActive 
                                        ? Colors.green.shade50 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.warehouse,
                                    color: warehouse.isActive 
                                        ? Colors.green.shade700 
                                        : Colors.grey.shade600,
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
                                            child: Text(
                                              warehouse.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (!warehouse.isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Neaktívny',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (warehouse.code != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Kód: ${warehouse.code}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      if (warehouse.address != null || warehouse.city != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${warehouse.address ?? ''}${warehouse.address != null && warehouse.city != null ? ', ' : ''}${warehouse.city ?? ''}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      if (warehouse.manager != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              warehouse.manager!,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateWarehouseScreen(),
            ),
          );
          if (result == true) {
            _loadWarehouses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


