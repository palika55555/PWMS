// Stub file for mobile_scanner on desktop platforms
import 'package:flutter/material.dart';

class MobileScannerController {
  void dispose() {}
  void stop() {}
  void start() {}
}

class MobileScanner extends StatelessWidget {
  final MobileScannerController controller;
  final Function(dynamic) onDetect;

  const MobileScanner({
    super.key,
    required this.controller,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Mobile Scanner not available on this platform'),
    );
  }
}

class Barcode {
  final String? rawValue;
  Barcode({this.rawValue});
}






