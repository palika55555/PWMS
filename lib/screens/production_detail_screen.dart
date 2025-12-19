import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../models/production.dart';
import '../services/api_service.dart';
import 'batch_detail_screen.dart';
import '../models/batch.dart';

class ProductionDetailScreen extends StatefulWidget {
  final Production production;

  const ProductionDetailScreen({
    super.key,
    required this.production,
  });

  @override
  State<ProductionDetailScreen> createState() => _ProductionDetailScreenState();
}

class _ProductionDetailScreenState extends State<ProductionDetailScreen> {
  Batch? _batch;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatch();
  }

  Future<void> _loadBatch() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final batches = await apiService.getBatches();
      try {
        final batch = batches.firstWhere(
          (b) => b.productionId == widget.production.id,
        );
        setState(() {
          _batch = batch;
          _isLoading = false;
        });
      } catch (e) {
        // Batch not found
        setState(() {
          _batch = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní šarže: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Výroba - ${widget.production.productionTypeName ?? 'Neznámy typ'}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Základné informácie
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Základné informácie',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Typ výroby', widget.production.productionTypeName ?? 'N/A'),
                          _buildInfoRow('Množstvo', '${widget.production.quantity.toStringAsFixed(2)}'),
                          if (widget.production.productionDate != null)
                            _buildInfoRow(
                              'Dátum výroby',
                              DateFormat('dd.MM.yyyy HH:mm').format(widget.production.productionDate!),
                            ),
                          if (widget.production.notes != null)
                            _buildInfoRow('Poznámky', widget.production.notes!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Batch informácie
                  if (_batch != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2, color: Colors.purple.shade700),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Šarža',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BatchDetailScreen(batch: _batch!),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Detail šarže'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Číslo šarže', _batch!.batchNumber),
                            _buildInfoRow('Status', _batch!.status),
                            _buildInfoRow('Množstvo', '${_batch!.quantity.toStringAsFixed(2)}'),
                            if (_batch!.warehouseLocation != null)
                              _buildInfoRow('Skladové miesto', _batch!.warehouseLocation!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // QR kód výroby
                  if (widget.production.qrCode != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.qr_code, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'QR Kód výroby',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: QrImageView(
                                  data: widget.production.qrCode!,
                                  version: QrVersions.auto,
                                  size: 200,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Materiály
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.science, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Použité materiály',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (widget.production.materials.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Žiadne materiály'),
                            )
                          else
                            ...widget.production.materials.map((material) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        material.materialName ?? 'Neznámy materiál',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      '${material.quantity.toStringAsFixed(2)} ${material.unit ?? ''}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

