// ====================================================================
// PALLET RECEIVE SCREEN - Flutter appka
// ====================================================================
// Obrazovka pre naskladňovanie paliet pomocou QR skenera

import 'package:flutter/material.dart';
import '../../services/pallet_receive_service.dart';
import '../../screens/qr_code/qr_scanner_wrapper.dart';

class PalletReceiveScreen extends StatefulWidget {
  const PalletReceiveScreen({super.key});

  @override
  State<PalletReceiveScreen> createState() => _PalletReceiveScreenState();
}

class _PalletReceiveScreenState extends State<PalletReceiveScreen> {
  List<String> _scannedQrCodes = [];
  List<Map<String, dynamic>> _receivedPallets = [];
  bool _isScanning = false;
  bool _isProcessing = false;
  int _quantityPerPallet = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naskladňovanie paliet'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Vymazať všetko',
          ),
        ],
      ),
      body: Column(
        children: [
          // Nastavenia
          _buildSettingsSection(),
          
          // Scan button
          _buildScanSection(),
          
          // Zoznam naskenovaných
          Expanded(
            child: _buildScannedList(),
          ),
          
          // Akcie
          _buildActionSection(),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text(
                'Nastavenia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Množstvo na paletu:'),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _quantityPerPallet.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onChanged: (value) {
                    final qty = int.tryParse(value);
                    if (qty != null && qty > 0) {
                      setState(() {
                        _quantityPerPallet = qty;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('ks'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '📦 Každá naskenovaná paleta sa automaticky pridá na sklad',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _startScanning,
            icon: _isScanning 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.qr_code_scanner),
            label: Text(_isScanning ? 'Skenovanie...' : 'Skenovať paletu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
          if (_scannedQrCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Naskenované: ${_scannedQrCodes.length} | Naskladnené: ${_receivedPallets.length}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannedList() {
    if (_scannedQrCodes.isEmpty) {
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
              'Žiadne naskenované palety',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Skenujte QR kód palety pre naskladnenie',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scannedQrCodes.length,
      itemBuilder: (context, index) {
        final qrCode = _scannedQrCodes[index];
        final isReceived = index < _receivedPallets.length;
        final palletData = isReceived ? _receivedPallets[index] : null;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isReceived ? Colors.green.shade50 : Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isReceived ? Colors.green : Colors.orange,
              child: Icon(
                isReceived ? Icons.check : Icons.pending,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              _extractPalletId(qrCode) ?? 'Neznáma paleta',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isReceived 
                ? '✅ Naskladnené (${_quantityPerPallet} ks PB-DT30)'
                : 'Čaká na spracovanie...',
              style: TextStyle(
                color: isReceived ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            trailing: isReceived 
              ? IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showPalletDetails(palletData),
                )
              : const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _buildActionSection() {
    if (_scannedQrCodes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processScannedPallets,
              icon: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.inventory_2),
              label: Text(_isProcessing ? 'Spracovávam...' : 'Naskladniť všetky'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear),
            label: const Text('Vymazať'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _startScanning() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final qrData = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => QrScannerMobile(),
        ),
      );

      if (qrData != null && qrData.isNotEmpty) {
        setState(() {
          _scannedQrCodes.add(qrData);
        });

        // Automaticky spracuj jednu paletu
        await _processSinglePallet(qrData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba pri skenovaní: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _processSinglePallet(String qrData) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await PalletReceiveService.receivePalletFromQR(
        context: context,
        qrData: qrData,
        quantity: _quantityPerPallet,
      );

      if (success) {
        setState(() {
          _receivedPallets.add({
            'qrData': qrData,
            'palletId': _extractPalletId(qrData),
            'quantity': _quantityPerPallet,
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (e) {
      // Chyba sa už zobrazila v servise
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processScannedPallets() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final successCount = await PalletReceiveService.receiveMultiplePalletsFromQR(
        context: context,
        qrCodes: _scannedQrCodes,
        quantity: _quantityPerPallet,
      );

      // Aktualizuj zoznam úspešne naskladnených
      setState(() {
        _receivedPallets.clear();
        for (int i = 0; i < successCount; i++) {
          _receivedPallets.add({
            'qrData': _scannedQrCodes[i],
            'palletId': _extractPalletId(_scannedQrCodes[i]),
            'quantity': _quantityPerPallet,
            'timestamp': DateTime.now(),
          });
        }
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _scannedQrCodes.clear();
      _receivedPallets.clear();
    });
  }

  String? _extractPalletId(String qrData) {
    try {
      if (qrData.startsWith('{')) {
        final data = Map<String, dynamic>.from(
          Uri.splitQueryString(qrData.substring(1, qrData.length - 1))
        );
        return data['palletId'] as String?;
      }
      
      final parts = qrData.split('|');
      if (parts.length >= 2) {
        return parts[0];
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showPalletDetails(Map<String, dynamic>? palletData) {
    if (palletData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail palety ${palletData['palletId']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID palety: ${palletData['palletId']}'),
            Text('Produkt: PB-DT30'),
            Text('Množstvo: ${palletData['quantity']} ks'),
            Text('Naskladnené: ${palletData['timestamp']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }
}
