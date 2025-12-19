import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class QRCodeScreenMobile extends StatefulWidget {
  const QRCodeScreenMobile({super.key});

  @override
  State<QRCodeScreenMobile> createState() => _QRCodeScreenMobileState();
}

class _QRCodeScreenMobileState extends State<QRCodeScreenMobile> {
  MobileScannerController controller = MobileScannerController();
  String? scannedData;
  bool isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skenovanie QR kódu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                isScanning = !isScanning;
                if (isScanning) {
                  controller.start();
                } else {
                  controller.stop();
                }
              });
            },
            tooltip: isScanning ? 'Pozastaviť' : 'Pokračovať',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null && barcode.rawValue != scannedData) {
                        setState(() {
                          scannedData = barcode.rawValue;
                          isScanning = false;
                        });
                        controller.stop();
                        _showScannedDataDialog(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Overlay s rámčekom
                CustomPaint(
                  painter: ScannerOverlay(),
                  child: Container(),
                ),
              ],
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
                        isScanning = true;
                      });
                      controller.start();
                    },
                    child: const Text('Skenovať znova'),
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
      // Nie je JSON, zobrazíme ako text
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                scannedData = null;
                isScanning = true;
              });
              controller.start();
            },
            child: const Text('Skenovať znova'),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    final scanPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(20)));

    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      scanPath,
    );

    canvas.drawPath(finalPath, paint);

    // Rámček
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(20)),
      borderPaint,
    );

    // Rohy
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;
    final cornerOffset = 10.0;

    // Ľavý horný
    canvas.drawLine(
      Offset(scanArea.left + cornerOffset, scanArea.top + cornerOffset),
      Offset(scanArea.left + cornerOffset + cornerLength, scanArea.top + cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left + cornerOffset, scanArea.top + cornerOffset),
      Offset(scanArea.left + cornerOffset, scanArea.top + cornerOffset + cornerLength),
      cornerPaint,
    );

    // Pravý horný
    canvas.drawLine(
      Offset(scanArea.right - cornerOffset, scanArea.top + cornerOffset),
      Offset(scanArea.right - cornerOffset - cornerLength, scanArea.top + cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right - cornerOffset, scanArea.top + cornerOffset),
      Offset(scanArea.right - cornerOffset, scanArea.top + cornerOffset + cornerLength),
      cornerPaint,
    );

    // Ľavý dolný
    canvas.drawLine(
      Offset(scanArea.left + cornerOffset, scanArea.bottom - cornerOffset),
      Offset(scanArea.left + cornerOffset + cornerLength, scanArea.bottom - cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left + cornerOffset, scanArea.bottom - cornerOffset),
      Offset(scanArea.left + cornerOffset, scanArea.bottom - cornerOffset - cornerLength),
      cornerPaint,
    );

    // Pravý dolný
    canvas.drawLine(
      Offset(scanArea.right - cornerOffset, scanArea.bottom - cornerOffset),
      Offset(scanArea.right - cornerOffset - cornerLength, scanArea.bottom - cornerOffset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right - cornerOffset, scanArea.bottom - cornerOffset),
      Offset(scanArea.right - cornerOffset, scanArea.bottom - cornerOffset - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

