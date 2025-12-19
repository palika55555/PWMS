import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

/// Zjednodušená web verzia QR scanneru
/// Používa JavaScript injection cez HtmlElementView
class QRCodeScreenWeb extends StatefulWidget {
  const QRCodeScreenWeb({super.key});

  @override
  State<QRCodeScreenWeb> createState() => _QRCodeScreenWebState();
}

class _QRCodeScreenWebState extends State<QRCodeScreenWeb> {
  String? scannedData;
  bool isScanning = false;
  String? containerId;

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  bool _isLibraryLoaded() {
    // Skontrolovať cez JavaScript
    return kIsWeb;
  }

  Future<void> _startScanning() async {
    if (!kIsWeb) return;

    setState(() {
      isScanning = true;
      containerId = 'qr-reader-${DateTime.now().millisecondsSinceEpoch}';
    });

    // JavaScript injection pre inicializáciu scanneru
    // Toto sa vykoná cez HtmlElementView widget
  }

  void _stopScanning() {
    if (containerId != null) {
      // Cleanup sa vykoná cez JavaScript
      containerId = null;
    }

    setState(() {
      isScanning = false;
    });
  }

  void _handleScannedData(String data) {
    setState(() {
      scannedData = data;
      isScanning = false;
    });
    _stopScanning();
    _showScannedDataDialog(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skenovanie QR kódu (Web)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: () {
              if (isScanning) {
                _stopScanning();
              } else {
                _startScanning();
              }
            },
            tooltip: isScanning ? 'Zastaviť' : 'Spustiť',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.green, width: 3),
              ),
              child: isScanning
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.green),
                          const SizedBox(height: 16),
                          const Text(
                            'Skenovanie...\nUmiestnite QR kód do rámčeka',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Poznámka: QR scanner na web vyžaduje JavaScript.\nPoužite mobilnú aplikáciu alebo iný QR scanner.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Pre skenovanie QR kódov použite mobilnú aplikáciu',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Informácie'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('QR Scanner na web'),
                                  content: const Text(
                                    'Web verzia QR scanneru je momentálne obmedzená.\n\n'
                                    'Pre plnú funkcionalitu:\n'
                                    '1. Použite mobilnú aplikáciu (Android/iOS)\n'
                                    '2. Alebo použite externý QR scanner a zadajte kód manuálne\n\n'
                                    'QR kódy môžete generovať v sekcii Výroba.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Zavrieť'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (scannedData != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Column(
                children: [
                  const Text(
                    'Naskenované:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scannedData!,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        scannedData = null;
                      });
                    },
                    child: const Text('Vymazať'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showScannedDataDialog(String data) {
    Map<String, dynamic>? parsedData;
    
    try {
      parsedData = jsonDecode(data);
    } catch (e) {
      // Nie je JSON
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naskenovaný QR kód'),
        content: SingleChildScrollView(
          child: parsedData != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parsedData['date'] != null)
                      Text('Dátum: ${parsedData['date']}'),
                    if (parsedData['batches'] != null)
                      Text('Počet šarží: ${parsedData['batches']}'),
                    if (parsedData['total_quantity'] != null)
                      Text('Celkom: ${parsedData['total_quantity']} ks'),
                    if (parsedData['products'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('Produkty:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(parsedData['products'] as Map<String, dynamic>).entries.map(
                        (e) => Text('  ${e.key}: ${e.value} ks'),
                      ),
                    ],
                    if (parsedData['batch_numbers'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('Čísla šarží:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(parsedData['batch_numbers'] as List).map(
                        (n) => Text('  $n'),
                      ),
                    ],
                  ],
                )
              : Text(data),
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
