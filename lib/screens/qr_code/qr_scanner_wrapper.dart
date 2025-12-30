// ====================================================================
// QR SCANNER WRAPPER - Flutter appka
// ====================================================================
// Tento wrapper poskytuje jednotné rozhranie pre QR skener
// Používa sa v product_pallets_screen pre skenovanie palet

import 'package:flutter/material.dart';
import 'qr_scanner_mobile.dart';

/// Jednoduchý wrapper pre QR skener
/// Vracia skenovaný text alebo null ak skenovanie bolo zrušené
class QrScannerMobile extends StatefulWidget {
  const QrScannerMobile({super.key});

  @override
  State<QrScannerMobile> createState() => _QrScannerMobileState();
}

class _QrScannerMobileState extends State<QrScannerMobile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skenovať QR kód'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: QrScannerMobileImpl(
        onScan: (code) {
          _showScanResult(code);
        },
      ),
    );
  }

  void _showScanResult(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naskenovaný QR kód'),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, code); // Return to previous screen with result
            },
            child: const Text('Použiť'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog only
            },
            child: const Text('Skenovať znova'),
          ),
        ],
      ),
    );
  }
}
