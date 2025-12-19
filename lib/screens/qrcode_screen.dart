import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'qrcode_screen_mobile.dart';
import 'qrcode_screen_web.dart';

class QRCodeScreen extends StatelessWidget {
  const QRCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pre web použiť web verziu
    if (kIsWeb) {
      return const QRCodeScreenWeb();
    }
    
    // Pre desktop (Windows/Linux/Mac) - zobraziť informáciu alebo web verziu
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Kód'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'QR Kód Scanner',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pre skenovanie QR kódov použite web verziu aplikácie\nalebo mobile aplikáciu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.language),
                  label: const Text('Otvoriť web verziu'),
                  onPressed: () {
                    // Otvoriť web verziu v prehliadači
                    // Môžeme spustiť lokálny server
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Pre mobile - použiť mobile scanner
    return const QRCodeScreenMobile();
  }
}
