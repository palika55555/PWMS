// ====================================================================
// PALLET ISSUE SCREEN - Flutter appka
// ====================================================================
// Obrazovka pre výdaj palet skenovaním QR kódu

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/pallet_service.dart';
import '../../screens/qr_code/qr_scanner_wrapper.dart';
import '../../models/product_pallet.dart';

class PalletIssueScreen extends StatefulWidget {
  const PalletIssueScreen({super.key});

  @override
  State<PalletIssueScreen> createState() => _PalletIssueScreenState();
}

class _PalletIssueScreenState extends State<PalletIssueScreen> {
  bool _isScanning = false;
  bool _isProcessing = false;
  List<ProductPallet> _issuedPallets = [];
  String _lastScannedCode = '';
  int _scanCount = 0;

  Future<void> _scanQrCode() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const QrScannerMobile(),
        ),
      );

      if (result != null && result.isNotEmpty) {
        await _processScannedCode(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba skenovania: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _processScannedCode(String qrData) async {
    setState(() {
      _isProcessing = true;
      _lastScannedCode = qrData;
    });

    try {
      final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
      final baseUrl = appSettingsProvider.apiBaseUrl;

      final result = await PalletService.scanPallet(
        baseUrl: baseUrl,
        mode: 'issue', // Výdaj palety
        palletId: _extractPalletId(qrData),
        productCode: _extractProductCode(qrData),
        raw: qrData,
      );

      setState(() {
        _issuedPallets.insert(0, result.item);
        _scanCount++;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Paleta ${result.item.palletId} vydaná'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba pri výdaji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String _extractPalletId(String qrData) {
    try {
      // Pokus o parsovanie JSON QR kódu
      if (qrData.startsWith('{')) {
        final data = Map<String, dynamic>.from(
          // Jednoduché parsovanie JSON (bez dart:convert pre jednoduchosť)
          qrData
              .replaceAll('{', '')
              .replaceAll('}', '')
              .replaceAll('"', '')
              .split(',')
              .map((e) => e.split(':'))
              .where((e) => e.length == 2)
              .fold<Map<String, String>>({}, (map, e) {
                map[e[0].trim()] = e[1].trim();
                return map;
              }),
        );
        return data['palletId'] ?? qrData;
      }
    } catch (e) {
      // Fallback na celý QR kód
    }
    return qrData;
  }

  String _extractProductCode(String qrData) {
    try {
      if (qrData.startsWith('{')) {
        final data = Map<String, dynamic>.from(
          qrData
              .replaceAll('{', '')
              .replaceAll('}', '')
              .replaceAll('"', '')
              .split(',')
              .map((e) => e.split(':'))
              .where((e) => e.length == 2)
              .fold<Map<String, String>>({}, (map, e) {
                map[e[0].trim()] = e[1].trim();
                return map;
              }),
        );
        return data['productCode'] ?? 'PB-DT30';
      }
    } catch (e) {
      // Fallback
    }
    return 'PB-DT30';
  }

  void _clearIssuedPallets() {
    setState(() {
      _issuedPallets.clear();
      _scanCount = 0;
      _lastScannedCode = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výdaj palet'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_issuedPallets.isNotEmpty)
            IconButton(
              onPressed: _clearIssuedPallets,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Vymazať zoznam',
            ),
        ],
      ),
      body: Column(
        children: [
          // Štatistiky
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Vydané palety', '$_scanCount', Icons.inventory_2_outlined),
                _buildStatItem('Posledný sken', _lastScannedCode.isEmpty ? 'Žiadny' : _lastScannedCode.substring(0, 15) + '...', Icons.qr_code),
              ],
            ),
          ),

          // Hlavný obsah
          Expanded(
            child: _issuedPallets.isEmpty
                ? _buildEmptyState()
                : _buildPalletsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning || _isProcessing ? null : _scanQrCode,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        icon: _isProcessing 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(_isProcessing ? 'Spracovávam...' : 'Skenovať paletu'),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange.shade700, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Žiadne vydané palety',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sknujte QR kód palety pre výdaj',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanQrCode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Začať skenovať'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPalletsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _issuedPallets.length,
      itemBuilder: (context, index) {
        final pallet = _issuedPallets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              pallet.palletId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${pallet.productCode} • ${pallet.quantity} ks • ${pallet.status}',
            ),
            trailing: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
            ),
          ),
        );
      },
    );
  }
}
