import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/batch.dart';
import '../services/api_service.dart';
import 'batch_detail_screen.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  List<Batch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final batches = await apiService.getBatches();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní šarží: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Čaká';
      case 'in_progress':
        return 'Prebieha';
      case 'completed':
        return 'Dokončené';
      case 'shipped':
        return 'Expedované';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Šarže'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Späť',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadne šarže',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(batch.status),
                          child: batch.qrCode != null
                              ? const Icon(Icons.qr_code, color: Colors.white)
                              : Text(
                                  batch.batchNumber.substring(0, 2).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                        title: Text(
                          'Šarža: ${batch.batchNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Množstvo: ${batch.quantity.toStringAsFixed(2)}'),
                            Text(
                              'Status: ${_getStatusText(batch.status)}',
                              style: TextStyle(
                                color: _getStatusColor(batch.status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (batch.warehouseLocation != null)
                              Text('Sklad: ${batch.warehouseLocation}'),
                            if (batch.createdAt != null)
                              Text(
                                'Vytvorené: ${DateFormat('dd.MM.yyyy HH:mm').format(batch.createdAt!)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        trailing: batch.qrCode != null
                            ? IconButton(
                                icon: const Icon(Icons.qr_code_scanner),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'QR Kód šarže',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                            const SizedBox(height: 16),
                                            QrImageView(
                                              data: batch.qrCode!,
                                              version: QrVersions.auto,
                                              size: 200.0,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              batch.batchNumber,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : null,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BatchDetailScreen(
                                batch: batch,
                              ),
                            ),
                          );
                          _loadBatches();
                        },
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}

