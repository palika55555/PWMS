import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/batch.dart';
import '../models/quality_control.dart';
import '../services/api_service.dart';
import 'quality_control_form_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final Batch batch;

  const BatchDetailScreen({
    super.key,
    required this.batch,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  List<QualityControl> _qualityTests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQualityTests();
  }

  Future<void> _loadQualityTests() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final tests = await apiService.getQualityTests(widget.batch.id);
      setState(() {
        _qualityTests = tests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Šarža ${widget.batch.batchNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQualityTests,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Číslo šarže: ${widget.batch.batchNumber}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (widget.batch.qrCode != null)
                          IconButton(
                            icon: const Icon(Icons.qr_code),
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
                                          data: widget.batch.qrCode!,
                                          version: QrVersions.auto,
                                          size: 200.0,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          widget.batch.batchNumber,
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
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Množstvo: ${widget.batch.quantity.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Text('Status: ${widget.batch.status}'),
                    if (widget.batch.warehouseLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Skladové miesto: ${widget.batch.warehouseLocation}'),
                      ),
                    if (widget.batch.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Vytvorené: ${DateFormat('dd.MM.yyyy HH:mm').format(widget.batch.createdAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kontrola kvality',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QualityControlFormScreen(
                          batchId: widget.batch.id,
                        ),
                      ),
                    );
                    _loadQualityTests();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Pridať test'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _qualityTests.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Žiadne testy kvality',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _qualityTests.length,
                        itemBuilder: (context, index) {
                          final test = _qualityTests[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: test.passed
                                    ? Colors.green
                                    : Colors.red,
                                child: Icon(
                                  test.passed ? Icons.check : Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(test.testName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Typ: ${test.testType}'),
                                  if (test.resultValue != null)
                                    Text('Výsledok: ${test.resultValue}'),
                                  if (test.resultText != null)
                                    Text('Text: ${test.resultText}'),
                                  if (test.testedAt != null)
                                    Text(
                                      'Testované: ${DateFormat('dd.MM.yyyy HH:mm').format(test.testedAt!)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              trailing: test.passed
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.cancel, color: Colors.red),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}

