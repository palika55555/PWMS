import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/batch.dart';
import '../services/api_client.dart';
import '../services/batches_api.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late final BatchesApi _batchesApi;
  late Future<Batch> _future;

  @override
  void initState() {
    super.initState();
    _batchesApi = BatchesApi(ApiClient());
    _future = _batchesApi.get(widget.batchId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _batchesApi.get(widget.batchId);
    });
  }

  Future<void> _addProductionEntry(Batch batch) async {
    final quantityCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'ks');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zaznamenať výrobu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(
                labelText: 'Množstvo',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Jednotka',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () {
              if (quantityCtrl.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Uložiť'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _batchesApi.addProductionEntry(
          widget.batchId,
          quantity: double.parse(quantityCtrl.text.trim()),
          unit: unitCtrl.text.trim().isEmpty ? 'ks' : unitCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Výroba zaznamenaná')),
          );
          await _reload();
          // Aktualizuj status na PRODUCED
          if (batch.status == 'DRAFT') {
            await _batchesApi.update(widget.batchId, status: 'PRODUCED');
            await _reload();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e')),
          );
        }
      }
    }
  }

  Future<void> _addQualityCheck() async {
    final checkedByCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool? approved;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Kontrola kvality'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Výsledok kontroly:'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Schválené')),
                  ButtonSegment(value: false, label: Text('Zamietnuté')),
                ],
                selected: approved == null ? <bool>{} : <bool>{approved!},
                onSelectionChanged: (selected) {
                  setState(() {
                    approved = selected.isNotEmpty ? selected.first : null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: checkedByCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kontroloval (voliteľné)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Poznámky',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: approved == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Uložiť'),
            ),
          ],
        ),
      ),
    );

    if (result == true && approved != null) {
      try {
        await _batchesApi.addQualityCheck(
          widget.batchId,
          approved: approved!,
          checkedBy: checkedByCtrl.text.trim().isEmpty
              ? null
              : checkedByCtrl.text.trim(),
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved!
                  ? 'Šarža schválená'
                  : 'Šarža zamietnutá'),
            ),
          );
          await _reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail šarže'),
      ),
      body: FutureBuilder<Batch>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Chyba: ${snapshot.error}'));
          }
          final batch = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                batch.recipeName ?? 'Bez receptúry',
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            _StatusChip(status: batch.status),
                          ],
                        ),
                        if (batch.productName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            batch.productName!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Dátum: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(batch.batchDate))}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (batch.notes != null && batch.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Poznámky: ${batch.notes}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (batch.recipeItems.isNotEmpty) ...[
                  Text(
                    'Materiály v receptúre',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: batch.recipeItems.map((item) {
                        return ListTile(
                          title: Text(item.materialName),
                          subtitle: Text(item.categoryLabel +
                              (item.materialFraction != null
                                  ? ' (${item.materialFraction})'
                                  : '')),
                          trailing: Text(
                            '${item.amount} ${item.unit}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Výroba',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (batch.productionEntries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Zatiaľ žiadne záznamy výroby',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: batch.productionEntries.map((entry) {
                        return ListTile(
                          title: Text('${entry.quantity} ${entry.unit}'),
                          subtitle: Text(
                            DateFormat('dd.MM.yyyy HH:mm')
                                .format(DateTime.parse(entry.createdAt)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addProductionEntry(batch),
                  icon: const Icon(Icons.add),
                  label: const Text('Zaznamenať výrobu'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kontrola kvality',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (batch.qualityChecks.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Zatiaľ žiadne kontroly kvality',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: batch.qualityChecks.map((check) {
                        return ListTile(
                          leading: Icon(
                            check.approved ? Icons.check_circle : Icons.cancel,
                            color: check.approved ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            check.approved ? 'Schválené' : 'Zamietnuté',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (check.checkedBy != null)
                                Text('Kontroloval: ${check.checkedBy}'),
                              if (check.notes != null) Text(check.notes!),
                              Text(
                                DateFormat('dd.MM.yyyy HH:mm')
                                    .format(DateTime.parse(check.createdAt)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addQualityCheck,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Pridať kontrolu kvality'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey;
      case 'PRODUCED':
        return Colors.blue;
      case 'QC_PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case 'DRAFT':
        return 'Koncept';
      case 'PRODUCED':
        return 'Vyrobené';
      case 'QC_PENDING':
        return 'Čaká na kontrolu';
      case 'APPROVED':
        return 'Schválené';
      case 'REJECTED':
        return 'Zamietnuté';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(context).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          color: _getStatusColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

