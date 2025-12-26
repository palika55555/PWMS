import 'package:flutter/material.dart';
// Import mobile_scanner only on mobile platforms
// On desktop, this file won't be used, so the import is safe
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerMobileImpl extends StatefulWidget {
  const QrScannerMobileImpl({super.key});

  @override
  State<QrScannerMobileImpl> createState() => _QrScannerMobileImplState();
}

class _QrScannerMobileImplState extends State<QrScannerMobileImpl> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _handleScannedCode(barcode.rawValue!);
              }
            }
          },
        ),
        // Overlay with instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Namieste QR kód do rámu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleScannedCode(String code) {
    controller.stop();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naskenovaný QR kód'),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.start();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

