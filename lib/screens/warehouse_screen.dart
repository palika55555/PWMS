import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/warehouse.dart';
import '../services/api_service.dart';
import 'warehouse_form_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Warehouse> _warehouse = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final warehouse = await apiService.getWarehouse();
      setState(() {
        _warehouse = warehouse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sklad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Späť',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Počet položiek: ${_warehouse.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WarehouseFormScreen(),
                            ),
                          );
                          _loadData();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Pridať na sklad'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _warehouse.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warehouse_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sklad je prázdny',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pridajte materiály na sklad',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _warehouse.length,
                          itemBuilder: (context, index) {
                            final item = _warehouse[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getQuantityColor(item.quantity),
                                  child: Text(
                                    item.quantity.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(item.materialName ?? 'Neznámy materiál'),
                                subtitle: Text('Jednotka: ${item.unit ?? 'N/A'}'),
                                trailing: Text(
                                  '${item.quantity} ${item.unit ?? ''}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                onTap: () {
                                  // TODO: Show edit dialog
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WarehouseFormScreen(),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getQuantityColor(double quantity) {
    if (quantity <= 10) return Colors.red;
    if (quantity <= 50) return Colors.orange;
    return Colors.green;
  }
}
