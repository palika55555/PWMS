import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';
import 'qr_scanner_mobile.dart';
import 'qr_scanner_desktop.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kód'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Use platform-specific scanner
          defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux ||
                  defaultTargetPlatform == TargetPlatform.macOS
              ? const QrScannerDesktop()
              : const QrScannerMobile(),
          const QrGeneratorScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Skenovať',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Generovať',
          ),
        ],
      ),
    );
  }
}

// Mobile scanner implementation
class QrScannerMobile extends StatelessWidget {
  const QrScannerMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return const QrScannerMobileImpl();
  }
}

// Desktop scanner implementation (Windows/Linux/macOS)
class QrScannerDesktop extends StatelessWidget {
  const QrScannerDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return const QrScannerDesktopImpl();
  }
}

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _textController = TextEditingController();
  String _qrData = 'ProBlock PWMS';

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _qrData = _textController.text.isEmpty
            ? 'ProBlock PWMS'
            : _textController.text;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _generateRandomCode() {
    final random = Random();
    final code = 'PB-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1000)}';
    _textController.text = code;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // QR Code display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 250,
            ),
          ),
          const SizedBox(height: 32),
          // Input field
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: 'Text alebo kód',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _generateRandomCode,
                tooltip: 'Generovať náhodný kód',
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Generate random button
          OutlinedButton.icon(
            onPressed: _generateRandomCode,
            icon: const Icon(Icons.shuffle),
            label: const Text('Generovať náhodný kód'),
          ),
        ],
      ),
    );
  }
}
