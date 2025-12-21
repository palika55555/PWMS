import 'package:flutter/material.dart';

class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR kód')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sem dáme skener (napr. mobile_scanner) a po naskenovaní otvoríme detail šarže / produktu.',
            ),
          ),
        ),
      ),
    );
  }
}


