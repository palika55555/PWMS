// ====================================================================
// SAVED LABELS SCREEN - Flutter appka
// ====================================================================
// Obrazovka pre zobrazenie a správu uložených vygenerovaných štítkov

import 'package:flutter/material.dart';
import '../../models/generated_labels_batch.dart';
import '../../models/pallet_label.dart';
import '../../services/generated_labels_service.dart';
import '../../services/pallet_label_service.dart';
import '../production/pallet_label_print_screen.dart';

class SavedLabelsScreen extends StatefulWidget {
  const SavedLabelsScreen({super.key});

  @override
  State<SavedLabelsScreen> createState() => _SavedLabelsScreenState();
}

class _SavedLabelsScreenState extends State<SavedLabelsScreen> {
  List<GeneratedLabelsBatch> _batches = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final batches = await GeneratedLabelsService.getAllBatches();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní: $e')),
        );
      }
    }
  }

  Future<void> _deleteBatch(GeneratedLabelsBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vymazať batch'),
        content: Text('Naozaj chcete vymazať batch ${batch.batchNumber} s ${batch.labels.length} štítkami?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GeneratedLabelsService.deleteBatch(batch.id);
        await _loadBatches();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch vymazaný')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba pri mazaní: $e')),
          );
        }
      }
    }
  }

  Future<void> _reprintBatch(GeneratedLabelsBatch batch) async {
    try {
      for (final label in batch.labels) {
        await PalletLabelService.printPalletLabel(label);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Vytičených ${batch.labels.length} štítkov')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri tlači: $e')),
        );
      }
    }
  }

  List<GeneratedLabelsBatch> get _filteredBatches {
    if (_searchQuery.isEmpty) return _batches;
    
    return _batches.where((batch) {
      return batch.batchNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             batch.labels.any((label) => 
                 label.palletId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 label.productCode.toLowerCase().contains(_searchQuery.toLowerCase())
             );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uložené štítky'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadBatches,
            icon: const Icon(Icons.refresh),
            tooltip: 'Obnoviť',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'cleanup':
                  _cleanupOldBatches();
                  break;
                case 'clear_all':
                  _clearAllBatches();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cleanup',
                child: Text('Vymazať staré (30+ dní)'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Vymazať všetko', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Vyhľadávanie
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Hľadať podľa šarže alebo ID palety...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Obsah
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBatches.isEmpty
                    ? _buildEmptyState()
                    : _buildBatchesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PalletLabelPrintScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nové štítky'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Žiadne uložené štítky',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vygenerujte nové štítky a objavia sa tu',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PalletLabelPrintScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Vytvoriť štítky'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBatches.length,
      itemBuilder: (context, index) {
        final batch = _filteredBatches[index];
        return _buildBatchCard(batch);
      },
    );
  }

  Widget _buildBatchCard(GeneratedLabelsBatch batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            '${batch.labels.length}',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          batch.batchNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(batch.displayDescription),
            const SizedBox(height: 4),
            Text(
              'Vytvorené: ${batch.formattedCreatedAt}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (batch.isSequential) ...[
              const SizedBox(height: 2),
              Text(
                'Postupné číslovanie od ${batch.startSequence}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'reprint':
                _reprintBatch(batch);
                break;
              case 'delete':
                _deleteBatch(batch);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reprint',
              child: Row(
                children: [
                  Icon(Icons.print, size: 16),
                  SizedBox(width: 8),
                  Text('Tlačiť znova'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Vymazať', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (batch.notes != null) ...[
                  Text(
                    'Poznámky: ${batch.notes}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Štítky na palety:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...batch.labels.map((label) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${label.palletId} - ${label.productCode} (${label.quantity} ks)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _printSingleLabel(label),
                        icon: const Icon(Icons.print, size: 16),
                        tooltip: 'Tlačiť tento štítok',
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printSingleLabel(PalletLabel label) async {
    try {
      await PalletLabelService.printPalletLabel(label);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Štítok ${label.palletId} vytičený')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri tlači: $e')),
        );
      }
    }
  }

  Future<void> _cleanupOldBatches() async {
    try {
      await GeneratedLabelsService.cleanupOldBatches();
      await _loadBatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staré batche vymazané')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri čistení: $e')),
        );
      }
    }
  }

  Future<void> _clearAllBatches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vymazať všetko'),
        content: const Text('Naozaj chcete vymazať všetky uložené štítky? Táto operácia je nezvratná.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať všetko', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GeneratedLabelsService.clearAllBatches();
        await _loadBatches();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Všetky štítky vymazané')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba pri mazaní: $e')),
          );
        }
      }
    }
  }
}
