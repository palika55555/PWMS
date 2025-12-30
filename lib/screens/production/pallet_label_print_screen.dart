// ====================================================================
// PALLET LABEL PRINT SCREEN - Flutter appka
// ====================================================================
// Obrazovka pre tlač štítkov na palety s debniacimi tvarnicami

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/database_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/batch.dart';
import '../../models/recipe.dart';
import '../../models/pallet_label.dart';
import '../../models/generated_labels_batch.dart';
import '../../services/pallet_label_service.dart';
import '../../services/pallet_service.dart';
import '../../services/generated_labels_service.dart';
import '../../services/inventory_check_service.dart';

class PalletLabelPrintScreen extends StatefulWidget {
  final Batch? batch;
  final String? productCode;
  
  const PalletLabelPrintScreen({
    super.key,
    this.batch,
    this.productCode,
  });

  @override
  State<PalletLabelPrintScreen> createState() => _PalletLabelPrintScreenState();
}

class _PalletLabelPrintScreenState extends State<PalletLabelPrintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _palletCountController = TextEditingController(text: '1');
  final _startSequenceController = TextEditingController(text: '1'); // Nové pole pre počiatočné číslo
  
  DateTime _productionDate = DateTime.now();
  DateTime? _packedAt;
  List<Batch> _batches = [];
  Batch? _selectedBatch;
  bool _isLoading = false;
  List<PalletLabel> _generatedLabels = [];
  bool _useSequentialNumbering = true; // Predvolené postupné číslovanie
  bool _addToWarehouse = true; // Automatické pridávanie na sklad

  @override
  void initState() {
    super.initState();
    _loadBatches();
    if (widget.batch != null) {
      _selectedBatch = widget.batch;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _palletCountController.dispose();
    _startSequenceController.dispose(); // Pridané
    super.dispose();
  }

  Future<void> _loadBatches() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final batches = await dbProvider.getBatches();
    final recipes = await dbProvider.getRecipes();
    
    // Filter pre PB-DT30 produkty - potrebujeme skontrolovať recipe pre každú batch
    final filteredBatches = batches.where((batch) {
      // Nájdi príslušnú receptúru pre túto batch
      final recipe = recipes.cast<Recipe?>().firstWhere(
        (r) => r?.id == batch.recipeId,
        orElse: () => null,
      );
      
      if (recipe == null) return false;
      
      // Skontroluj produktový typ alebo názov receptúry
      return recipe.productType == 'PB-DT30' ||
             recipe.productType.toLowerCase().contains('dt30') ||
             recipe.name.toLowerCase().contains('dt30') ||
             recipe.name.toLowerCase().contains('pb-dt30');
    }).toList();
    
    setState(() {
      _batches = filteredBatches;
      if (_selectedBatch == null && filteredBatches.isNotEmpty) {
        _selectedBatch = filteredBatches.first;
      }
    });
  }

  void _generateLabels() async {
    if (!_formKey.currentState!.validate() || _selectedBatch == null) return;

    final palletCount = int.tryParse(_palletCountController.text) ?? 1;
    if (palletCount < 1 || palletCount > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Počet palet musí byť medzi 1 a 50')),
      );
      return;
    }

    final startSequence = int.tryParse(_startSequenceController.text) ?? 1;
    if (startSequence < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Počiatočné číslo musí byť väčšie ako 0')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedLabels.clear();
    });

    try {
      // 1. Skontroluj, či produkt PB-DT30 existuje na sklade
      final totalQuantity = palletCount * 30; // 30 ks na paletu
      final productExists = await InventoryCheckService.ensurePbDt30Exists(
        context: context,
        quantity: totalQuantity,
      );

      if (!productExists) {
        // Používateľ zrušil vytvorenie produktu
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Vygeneruj štítky
      final labels = PalletLabel.generatePalletLabelsForPbDt30(
        batchNumber: _selectedBatch!.batchNumber,
        productionDate: _productionDate,
        palletCount: palletCount,
        packedAt: _packedAt,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        startSequence: _useSequentialNumbering ? startSequence : 1,
      );

      setState(() {
        _generatedLabels = labels;
        _isLoading = false;
      });

      // 3. Automatické pridávanie palet na sklad
      if (_addToWarehouse) {
        await _addPalletsToWarehouse(labels);
      }

      // 4. Uloženie vygenerovaných štítkov pre neskoršie použitie
      await _saveGeneratedLabels(labels);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Vygenerovaných $palletCount štítkov ($totalQuantity ks)${_useSequentialNumbering ? ' (postupné číslovanie)' : ''}${_addToWarehouse ? ' a pridané na sklad' : ''} ✅ Uložené pre neskoršie použitie')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri generovaní štítkov: $e')),
      );
    }
  }

  /// Pridá vygenerované palety na sklad (backend)
  Future<void> _addPalletsToWarehouse(List<PalletLabel> labels) async {
    try {
      final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
      final baseUrl = appSettingsProvider.apiBaseUrl;

      // Príprava dát pre hromadné vytvorenie
      final palletsData = labels.map((label) => {
        'palletId': label.palletId,
        'productCode': label.productCode,
        'quantity': label.quantity,
        'batchNumber': label.batchNumber,
        'notes': label.notes,
      }).toList();

      // Pokus o hromadné vytvorenie
      try {
        await PalletService.createMultiplePallets(
          baseUrl: baseUrl,
          pallets: palletsData,
        );
      } catch (e) {
        // Ak hromadné vytvorenie nie je podporované, vytvárame jednotlivo
        for (final palletData in palletsData) {
          await PalletService.createPallet(
            baseUrl: baseUrl,
            palletId: palletData['palletId'] as String,
            productCode: palletData['productCode'] as String,
            quantity: palletData['quantity'] as int,
            batchNumber: palletData['batchNumber'] as String?,
            notes: palletData['notes'] as String?,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${labels.length} palet úspešne pridaných na sklad'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Chyba pri pridávaní na sklad: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Uloží vygenerované štítky do lokálneho úložiska
  Future<void> _saveGeneratedLabels(List<PalletLabel> labels) async {
    try {
      if (_selectedBatch == null) return;
      
      final startSequence = int.tryParse(_startSequenceController.text) ?? 1;
      
      final batch = GeneratedLabelsBatch.create(
        batchNumber: _selectedBatch!.batchNumber,
        labels: labels,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        isSequential: _useSequentialNumbering,
        startSequence: startSequence,
      );

      await GeneratedLabelsService.saveGeneratedBatch(batch);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${labels.length} štítkov uložených pre neskoršie použitie'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Chyba pri ukladaní štítkov: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _printLabel(PalletLabel label) async {
    try {
      await PalletLabelService.printPalletLabel(label);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri tlači štítka: $e')),
        );
      }
    }
  }

  Future<void> _printAllLabels() async {
    if (_generatedLabels.isEmpty) return;

    try {
      for (final label in _generatedLabels) {
        await PalletLabelService.printPalletLabel(label);
        // Malá pauza medzi tlačou pre spoľahlivosť
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vytičených ${_generatedLabels.length} štítkov')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri tlači štítkov: $e')),
        );
      }
    }
  }

  Future<void> _shareLabel(PalletLabel label) async {
    try {
      await PalletLabelService.sharePalletLabel(label);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri zdieľaní štítka: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tlač štítkov palet'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informácie o produkte
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produkt: Debniaca tvarnica PB-DT30',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Špecifikácia:'),
                      const Text('• Počet na palete: 30 ks'),
                      const Text('• Hmotnosť palety: 840 kg'),
                      const Text('• QR kód pre sledovanie'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Výber šarže
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Výber šarže',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_batches.isEmpty)
                        const Text('Nenašli sa žiadne šarže pre PB-DT30')
                      else
                        DropdownButtonFormField<Batch>(
                          value: _selectedBatch,
                          decoration: const InputDecoration(
                            labelText: 'Šarža',
                            border: OutlineInputBorder(),
                          ),
                          items: _batches.map((batch) {
                            return DropdownMenuItem(
                              value: batch,
                              child: Text('${batch.batchNumber} (${DateFormat('dd.MM.yyyy').format(DateTime.parse(batch.productionDate))})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBatch = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) return 'Prosím vyberte šaržu';
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Nastavenia štítkov
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nastavenia štítkov',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Počet palet
                      TextFormField(
                        controller: _palletCountController,
                        decoration: const InputDecoration(
                          labelText: 'Počet palet',
                          border: OutlineInputBorder(),
                          helperText: 'Maximálne 50 štítkov naraz',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final count = int.tryParse(value ?? '');
                          if (count == null || count < 1 || count > 50) {
                            return 'Počet musí byť medzi 1 a 50';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Dátum výroby
                      ListTile(
                        title: const Text('Dátum výroby'),
                        subtitle: Text(DateFormat('dd.MM.yyyy').format(_productionDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _productionDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _productionDate = date;
                            });
                          }
                        },
                      ),
                      
                      // Dátum balenia
                      ListTile(
                        title: const Text('Dátum balenia'),
                        subtitle: Text(_packedAt != null 
                          ? DateFormat('dd.MM.yyyy').format(_packedAt!)
                          : 'Dnes'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _packedAt ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _packedAt = date;
                            });
                          }
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Postupné číslovanie
                      SwitchListTile(
                        title: const Text('Postupné číslovanie palet'),
                        subtitle: const Text('Palety budú mať ID: PAL-20251230-001, 002, 003...'),
                        value: _useSequentialNumbering,
                        onChanged: (value) {
                          setState(() {
                            _useSequentialNumbering = value;
                          });
                        },
                        activeColor: Colors.blue.shade700,
                      ),
                      
                      // Automatické pridávanie na sklad
                      SwitchListTile(
                        title: const Text('Automaticky pridať na sklad'),
                        subtitle: const Text('Palety sa po vygenerovaní pridajú do skladového systému'),
                        value: _addToWarehouse,
                        onChanged: (value) {
                          setState(() {
                            _addToWarehouse = value;
                          });
                        },
                        activeColor: Colors.green.shade700,
                      ),
                      
                      if (_addToWarehouse) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_upload, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Palety budú synchronizované s backendom a dostupné pre skenovanie vo warehouse.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (_useSequentialNumbering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _startSequenceController,
                          decoration: const InputDecoration(
                            labelText: 'Počiatočné číslo palety',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                            helperText: 'Číslo prvej palety (napr. 1 = PAL-20251230-001)',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            if (number == null || number < 1) {
                              return 'Číslo musí byť väčšie ako 0';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Príklad: Ak zadáte 1 a počet palet 3, vytvoria sa:\n'
                                  'PAL-${DateFormat('yyyyMMdd').format(DateTime.now())}-001\n'
                                  'PAL-${DateFormat('yyyyMMdd').format(DateTime.now())}-002\n'
                                  'PAL-${DateFormat('yyyyMMdd').format(DateTime.now())}-003',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      // Poznámky
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Poznámky (voliteľné)',
                          border: OutlineInputBorder(),
                          helperText: 'Maximálne 100 znakov',
                        ),
                        maxLength: 100,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tlačidlo pre generovanie
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _generateLabels,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Generovať štítky'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Zoznam vygenerovaných štítkov
              if (_generatedLabels.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vygenerované štítky (${_generatedLabels.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _printAllLabels,
                              icon: const Icon(Icons.print),
                              label: const Text('Tlačiť všetky'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Zoznam štítkov
                        ..._generatedLabels.asMap().entries.map((entry) {
                          final index = entry.key;
                          final label = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(label.palletId),
                              subtitle: Text(
                                'Šarža: ${label.batchNumber} | ${label.formattedProductionDate}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code),
                                    onPressed: () => _showQrDialog(label),
                                    tooltip: 'Zobraziť QR kód',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.print),
                                    onPressed: () => _printLabel(label),
                                    tooltip: 'Tlačiť štítok',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share),
                                    onPressed: () => _shareLabel(label),
                                    tooltip: 'Zdieľať PDF',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showQrDialog(PalletLabel label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR kód - ${label.palletId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: label.qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text(
              'Produkt: ${label.productCode}\\n'
              'Šarža: ${label.batchNumber}\\n'
              'Množstvo: ${label.quantity} ks\\n'
              'Hmotnosť: ${label.formattedWeight}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }
}
