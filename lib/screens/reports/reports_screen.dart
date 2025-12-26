import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' show Batch, Material, StockMovement;
import 'export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'batches';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Správy a Exporty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
            tooltip: 'Exportovať',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtre',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Report type
                  DropdownButtonFormField<String>(
                    value: _selectedReportType,
                    decoration: const InputDecoration(
                      labelText: 'Typ správy',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'batches',
                        child: Text('Šarže'),
                      ),
                      DropdownMenuItem(
                        value: 'materials',
                        child: Text('Materiály'),
                      ),
                      DropdownMenuItem(
                        value: 'stock',
                        child: Text('Skladové pohyby'),
                      ),
                      DropdownMenuItem(
                        value: 'quality',
                        child: Text('Kvalita'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedReportType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date range
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Od',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('d. M. yyyy', 'sk_SK').format(_startDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Do',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('d. M. yyyy', 'sk_SK').format(_endDate),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Report preview
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreview() {
    switch (_selectedReportType) {
      case 'batches':
        return _buildBatchesPreview();
      case 'materials':
        return _buildMaterialsPreview();
      case 'stock':
        return _buildStockPreview();
      case 'quality':
        return _buildQualityPreview();
      default:
        return const Center(child: Text('Vyberte typ správy'));
    }
  }

  Widget _buildBatchesPreview() {
    return FutureBuilder<List<Batch>>(
      future: Provider.of<DatabaseProvider>(context, listen: false).getBatches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final batches = snapshot.data!.where((b) {
          final date = DateTime.parse(b.productionDate);
          return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                 date.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        if (batches.isEmpty) {
          return const Center(child: Text('Žiadne dáta'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final batch = batches[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(batch.batchNumber),
                subtitle: Text(
                  DateFormat('d. M. yyyy', 'sk_SK').format(
                    DateTime.parse(batch.productionDate),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${batch.quantity} ks'),
                    Text(
                      _getStatusText(batch.qualityStatus),
                      style: TextStyle(
                        color: _getStatusColor(batch.qualityStatus),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialsPreview() {
    return FutureBuilder<List<Material>>(
      future: Provider.of<DatabaseProvider>(context, listen: false).getMaterials(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final material = snapshot.data![index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(material.name),
                subtitle: Text('Typ: ${material.type}'),
                trailing: Text(
                  '${material.currentStock} ${material.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: material.currentStock <= material.minStock
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockPreview() {
    return FutureBuilder<List<StockMovement>>(
      future: Provider.of<DatabaseProvider>(context, listen: false).getStockMovements(
        fromDate: _startDate,
        toDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Žiadne dáta'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final movement = snapshot.data![index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_getMovementTypeText(movement.movementType)),
                subtitle: Text(
                  DateFormat('d. M. yyyy', 'sk_SK').format(
                    DateTime.parse(movement.movementDate),
                  ),
                ),
                trailing: Text(
                  '${movement.quantity > 0 ? '+' : ''}${movement.quantity} ${movement.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: movement.quantity > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQualityPreview() {
    return FutureBuilder<List<Batch>>(
      future: Provider.of<DatabaseProvider>(context, listen: false).getBatches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final batches = snapshot.data!.where((b) {
          final date = DateTime.parse(b.productionDate);
          return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                 date.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

        final approved = batches.where((b) => b.qualityStatus == 'approved').length;
        final rejected = batches.where((b) => b.qualityStatus == 'rejected').length;
        final pending = batches.where((b) => b.qualityStatus == 'pending').length;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatRow('Schválené', approved, Colors.green),
                      const Divider(),
                      _buildStatRow('Zamietnuté', rejected, Colors.red),
                      const Divider(),
                      _buildStatRow('Čakajúce', pending, Colors.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Future<void> _exportReport() async {
    setState(() => _loading = true);
    
    try {
      final exportService = ExportService();
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      switch (_selectedReportType) {
        case 'batches':
          final batches = await dbProvider.getBatches();
          await exportService.exportBatches(batches, _startDate, _endDate);
          break;
        case 'materials':
          final materials = await dbProvider.getMaterials();
          await exportService.exportMaterials(materials);
          break;
        case 'stock':
          final movements = await dbProvider.getStockMovements(
            fromDate: _startDate,
            toDate: _endDate,
          );
          await exportService.exportStockMovements(movements);
          break;
      }
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Správa bola exportovaná'),
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
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri exporte: $e'),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      case 'pending':
        return 'Čaká';
      default:
        return 'Neznámy';
    }
  }

  String _getMovementTypeText(String type) {
    switch (type) {
      case 'receipt':
        return 'Príjem';
      case 'issue':
        return 'Výdaj';
      case 'inventory_adjustment':
        return 'Inventúra';
      default:
        return type;
    }
  }
}


