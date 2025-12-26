import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/supplier.dart';
import 'create_supplier_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final suppliers = await dbProvider.getSuppliers();
    setState(() {
      _suppliers = suppliers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodávatelia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateSupplierScreen(),
                ),
              );
              if (result == true) {
                _loadSuppliers();
              }
            },
            tooltip: 'Nový dodávateľ',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadni dodávatelia',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateSupplierScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadSuppliers();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Pridať prvého dodávateľa'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSuppliers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _suppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _suppliers[index];
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
                                builder: (context) => CreateSupplierScreen(supplier: supplier),
                              ),
                            );
                            if (result == true) {
                              _loadSuppliers();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    color: Colors.blue.shade700,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplier.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (supplier.companyId != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'IČO: ${supplier.companyId}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      if (supplier.phone != null || supplier.email != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (supplier.phone != null) ...[
                                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                supplier.phone!,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            if (supplier.phone != null && supplier.email != null)
                                              Text(' • ', style: TextStyle(color: Colors.grey[600])),
                                            if (supplier.email != null)
                                              Expanded(
                                                child: Text(
                                                  supplier.email!,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
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
              builder: (context) => const CreateSupplierScreen(),
            ),
          );
          if (result == true) {
            _loadSuppliers();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}






