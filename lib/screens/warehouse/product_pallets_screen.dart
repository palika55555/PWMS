// ====================================================================
// PRODUCT PALLETS SCREEN - Flutter appka
// ====================================================================
// Tento screen zobrazuje a spravuje produktové palety
// Synchronizuje sa s backendom a QR webom

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product_pallet.dart';
import '../../services/pallet_service.dart';
import '../../screens/qr_code/qr_scanner_wrapper.dart';
import '../../utils/qr_payload.dart';
import '../../providers/app_settings_provider.dart';

/// Screen pre zobrazenie a správu produktových paliet
/// Zobrazuje zoznam paliet, umožňuje filtrovanie, skenovanie a detaily
class ProductPalletsScreen extends StatefulWidget {
  const ProductPalletsScreen({super.key});

  @override
  State<ProductPalletsScreen> createState() => _ProductPalletsScreenState();
}

class _CreatePalletPayload {
  final String palletId;
  final String productCode;
  final int quantity;
  final String? batchNumber;

  const _CreatePalletPayload({
    required this.palletId,
    required this.productCode,
    required this.quantity,
    this.batchNumber,
  });
}

class _ProductPalletsScreenState extends State<ProductPalletsScreen> {
  // State variables
  List<ProductPallet> _pallets = [];
  List<ProductPallet> _filteredPallets = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadPallets();
  }

  Future<void> _createPalletManual() async {
    try {
      final settings = context.read<AppSettingsProvider>();
      await settings.ready;
      final baseUrl = settings.apiBaseUrl;

      final isConnected = await PalletService.testConnection(baseUrl: baseUrl);
      if (!isConnected) {
        _showError('Nepodarilo sa pripojiť k serveru');
        return;
      }

      final payload = await _showCreatePalletDialog();
      if (payload == null) return;

      setState(() => _isLoading = true);

      final raw = QrPayload.pallet(
        palletId: payload.palletId,
        productCode: payload.productCode,
        batchNumber: payload.batchNumber,
        qty: payload.quantity,
        packedAtIso: DateTime.now().toIso8601String(),
      );

      final result = await PalletService.scanPallet(
        baseUrl: baseUrl,
        mode: 'receive',
        palletId: payload.palletId,
        productCode: payload.productCode,
        raw: raw,
        quantity: payload.quantity,
      );

      await _loadPallets();
      _showSuccess('Paleta ${result.item.palletId} bola vytvorená na sklade');
    } catch (e) {
      _showError('Chyba pri vytváraní palety: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<_CreatePalletPayload?> _showCreatePalletDialog() async {
    final palletIdController = TextEditingController();
    final productCodeController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final batchController = TextEditingController();

    final result = await showDialog<_CreatePalletPayload>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vytvoriť paletu na sklad'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: palletIdController,
                decoration: const InputDecoration(
                  labelText: 'ID palety',
                  hintText: 'napr. PAL123',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productCodeController,
                decoration: const InputDecoration(
                  labelText: 'Produkt',
                  hintText: 'napr. DT20',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Množstvo (ks)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Šarža (voliteľné)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              final palletId = palletIdController.text.trim();
              final productCode = productCodeController.text.trim();
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              final batchNumber = batchController.text.trim();

              if (palletId.isEmpty || productCode.isEmpty || qty <= 0) {
                return;
              }

              Navigator.pop(
                context,
                _CreatePalletPayload(
                  palletId: palletId,
                  productCode: productCode,
                  quantity: qty,
                  batchNumber: batchNumber.isEmpty ? null : batchNumber,
                ),
              );
            },
            child: const Text('Vytvoriť'),
          ),
        ],
      ),
    );

    palletIdController.dispose();
    productCodeController.dispose();
    qtyController.dispose();
    batchController.dispose();

    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Načítanie zoznamu paliet z backendu
  Future<void> _loadPallets() async {
    setState(() => _isLoading = true);
    
    try {
      final settings = context.read<AppSettingsProvider>();
      await settings.ready;
      final pallets = await PalletService.getPallets(baseUrl: settings.apiBaseUrl);
      setState(() {
        _pallets = pallets;
        _applyFilters();
      });
    } catch (e) {
      _showError('Chyba pri načítaní paliet: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Obnovenie zoznamu paliet (pull-to-refresh)
  Future<void> _refreshPallets() async {
    try {
      final settings = context.read<AppSettingsProvider>();
      await settings.ready;
      final pallets = await PalletService.getPallets(baseUrl: settings.apiBaseUrl);
      setState(() {
        _pallets = pallets;
        _applyFilters();
      });
    } catch (e) {
      _showError('Chyba pri obnovení: ${e.toString()}');
    }
  }

  /// Aplikovanie filtrov (vyhľadávanie a status)
  void _applyFilters() {
    setState(() {
      _filteredPallets = _pallets.where((pallet) {
        // Filtrovanie podľa statusu
        if (_selectedStatus != 'all' && pallet.status != _selectedStatus) {
          return false;
        }
        
        // Filtrovanie podľa vyhľadávania
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return pallet.palletId.toLowerCase().contains(query) ||
                 pallet.productCode.toLowerCase().contains(query) ||
                 (pallet.lastRaw?.toLowerCase().contains(query) ?? false);
        }
        
        return true;
      }).toList();
    });
  }

  /// Skenovanie QR kódu a pridanie palety
  Future<void> _scanQrCode() async {
    try {
      final settings = context.read<AppSettingsProvider>();
      await settings.ready;
      final baseUrl = settings.apiBaseUrl;

      // Test pripojenia
      final isConnected = await PalletService.testConnection(baseUrl: baseUrl);
      if (!isConnected) {
        _showError('Nepodarilo sa pripojiť k serveru');
        return;
      }

      // Spustenie QR skenera
      final qrData = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerMobile()),
      );

      if (qrData != null && qrData.isNotEmpty) {
        await _processQrData(qrData, baseUrl);
      }
    } catch (e) {
      _showError('Chyba pri skenovaní: ${e.toString()}');
    }
  }

  /// Spracovanie QR dát a pridanie palety
  Future<void> _processQrData(String qrData, String baseUrl) async {
    try {
      // Pokus o parsovanie JSON formátu
      Map<String, dynamic> json;
      try {
        json = jsonDecode(qrData) as Map<String, dynamic>;
      } catch (e) {
        // Ak to nie je JSON, skúsime delimited formát
        final palletQrData = PalletQrData.fromDelimited(qrData);
        json = {
          'palletId': palletQrData.palletId,
          'productCode': palletQrData.productCode,
          'quantity': palletQrData.quantity,
          'batchNumber': palletQrData.batchNumber,
        };
      }

      if (json['palletId'] == null) {
        _showError('Neplatný formát QR kódu');
        return;
      }

      final dynamic qtyAny = json['quantity'] ?? json['qty'] ?? json['ks'] ?? json['pcs'];
      final int? qty = qtyAny is int ? qtyAny : (qtyAny is num ? qtyAny.toInt() : int.tryParse('$qtyAny'));

      // Zobrazenie dialógu pre potvrdenie
      final confirmed = await _showScanConfirmationDialog(json);
      if (!confirmed) return;

      // Odoslanie na backend
      setState(() => _isLoading = true);
      
      final result = await PalletService.scanPallet(
        baseUrl: baseUrl,
        mode: 'receive', // Predpokladáme príjem na sklad
        palletId: json['palletId'] as String,
        productCode: json['productCode'] as String? ?? 'UNKNOWN',
        raw: qrData,
        quantity: qty,
      );

      // Obnovenie zoznamu
      await _loadPallets();

      _showSuccess('Paleta ${result.item.palletId} bola pridaná na sklad');
    } catch (e) {
      _showError('Chyba pri spracovaní QR kódu: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Zobrazenie potvrdzovacieho dialógu pre skenovanie
  Future<bool> _showScanConfirmationDialog(Map<String, dynamic> qrData) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pridať paletu na sklad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID palety: ${qrData['palletId']}'),
            Text('Produkt: ${qrData['productCode'] ?? 'UNKNOWN'}'),
            if (qrData['quantity'] != null) Text('Množstvo: ${qrData['quantity']}'),
            if (qrData['batchNumber'] != null) Text('Šarža: ${qrData['batchNumber']}'),
            const SizedBox(height: 16),
            const Text('Chcete pridať túto paletu na sklad?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pridať'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Zobrazenie detailov palety
  void _showPalletDetails(ProductPallet pallet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductPalletDetailScreen(pallet: pallet),
      ),
    );
  }

  /// Zobrazenie chybového hlásenia
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Zobrazenie úspešného hlásenia
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palety na sklade'),
        actions: [
          IconButton(
            onPressed: _createPalletManual,
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Vytvoriť paletu',
          ),
          // Filter button
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedStatus = value;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Všetky')),
              const PopupMenuItem(value: 'in_stock', child: Text('Na sklade')),
              const PopupMenuItem(value: 'issued', child: Text('Vydané')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Hľadať podľa ID, produktu alebo QR...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // Status filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('all', 'Všetky'),
                const SizedBox(width: 8),
                _buildFilterChip('in_stock', 'Na sklade'),
                const SizedBox(width: 8),
                _buildFilterChip('issued', 'Vydané'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Pallet list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refreshPallets,
                    child: _filteredPallets.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _filteredPallets.length,
                            itemBuilder: (context, index) {
                              final pallet = _filteredPallets[index];
                              return _buildPalletCard(pallet);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanQrCode,
        child: const Icon(Icons.qr_code_scanner),
        tooltip: 'Skenovať QR kód',
      ),
    );
  }

  /// Vytvorenie filter chipu
  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
          _applyFilters();
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
    );
  }

  /// Vytvorenie karty palety
  Widget _buildPalletCard(ProductPallet pallet) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pallet.isInStock ? Colors.green : Colors.orange,
          child: Icon(
            pallet.isInStock ? Icons.inventory : Icons.outbox,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(pallet.displayTitle),
        subtitle: Text(pallet.displaySubtitle),
        trailing: Text(
          pallet.statusText,
          style: TextStyle(
            color: pallet.isInStock ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _showPalletDetails(pallet),
      ),
    );
  }

  /// Zobrazenie prázdneho stavu
  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _selectedStatus != 'all';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_list : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'Žiadne palety nevyhovujú filtru' : 'Žiadne palety na sklade',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 8),
            Text(
              'Skenujte QR kód pre pridanie palety',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Screen pre detailné zobrazenie palety
class ProductPalletDetailScreen extends StatelessWidget {
  final ProductPallet pallet;

  const ProductPalletDetailScreen({
    super.key,
    required this.pallet,
  });

  @override
  Widget build(BuildContext context) {
    final qrPayload = _buildPalletQrPayload();

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail palety ${pallet.palletId}'),
        actions: [
          IconButton(
            tooltip: 'Kopírovať QR payload',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: qrPayload));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR payload skopírovaný')),
              );
            },
          ),
          IconButton(
            tooltip: 'Tlačiť štítok',
            icon: const Icon(Icons.print),
            onPressed: () => _printLabel(context, qrPayload),
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
                    Text(
                      'QR kód',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 220,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${pallet.quantity} ks | ${_formatDateOnly(pallet.firstSeenAt)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${pallet.palletId} • ${pallet.productCode}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hlavné informácie
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Základné informácie',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('ID palety', pallet.palletId),
                    _buildDetailRow('Produkt', pallet.productCode),
                    _buildDetailRow('Množstvo', '${pallet.quantity}'),
                    _buildDetailRow('Stav', pallet.statusText),
                    _buildDetailRow('Zdroj', pallet.source ?? 'Neznámy'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Časové informácie
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Časové informácie',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Prvýkrát videná',
                      _formatDateTime(pallet.firstSeenAt),
                    ),
                    _buildDetailRow(
                      'Posledne videná',
                      _formatDateTime(pallet.lastSeenAt),
                    ),
                    _buildDetailRow(
                      'Vytvorená',
                      _formatDateTime(pallet.createdAt),
                    ),
                    _buildDetailRow(
                      'Aktualizovaná',
                      _formatDateTime(pallet.updatedAt),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // QR dáta
            if (pallet.lastRaw != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR dáta',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pallet.lastRaw!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }

  String _buildPalletQrPayload() {
    // Prefer raw QR payload if it already contains pallet JSON (so we preserve batchNumber/packedAt if present)
    final raw = pallet.lastRaw;
    if (raw != null && raw.trim().isNotEmpty) {
      final t = raw.trim();
      if (t.startsWith('{') && t.endsWith('}')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map<String, dynamic>) {
            final isPallet = decoded['t'] == 'pallet' || decoded['kind'] == 'pallet';
            final hasPalletId = decoded['palletId'] != null || decoded['pallet_id'] != null;
            if (isPallet || hasPalletId) return t;
          }
        } catch (_) {
          // ignore
        }
      }
    }

    return QrPayload.pallet(
      palletId: pallet.palletId,
      productCode: pallet.productCode,
      batchNumber: null,
      qty: pallet.quantity,
      packedAtIso: pallet.firstSeenAt.toIso8601String(),
    );
  }

  Future<void> _printLabel(BuildContext context, String qrPayload) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrPayload,
                  width: 180,
                  height: 180,
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '${pallet.quantity} ks | ${_formatDateOnly(pallet.firstSeenAt)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text('${pallet.palletId} • ${pallet.productCode}', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'pallet_${pallet.palletId}.pdf',
    );
  }
}
