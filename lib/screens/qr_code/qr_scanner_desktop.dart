import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScannerDesktopImpl extends StatefulWidget {
  const QrScannerDesktopImpl({super.key});

  @override
  State<QrScannerDesktopImpl> createState() => _QrScannerDesktopImplState();
}

class _QrScannerDesktopImplState extends State<QrScannerDesktopImpl> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleScannedCode(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naskenovaný QR kód'),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _textController.clear();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      _textController.text = clipboardData.text!;
      _handleScannedCode(clipboardData.text!);
    } else {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Schránka je prázdna'),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 120,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 32),
          Text(
            'QR Kód Scanner pre Windows',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Na Windows môžete zadať QR kód manuálne alebo použiť webkameru (ak je nainštalovaná podpora)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: 'Zadajte alebo vložte QR kód',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                onPressed: _pasteFromClipboard,
                tooltip: 'Vložiť zo schránky',
              ),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _handleScannedCode(value);
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_textController.text.isNotEmpty) {
                _handleScannedCode(_textController.text);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('Vyhľadať'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.paste),
            label: const Text('Vložiť zo schránky'),
          ),
        ],
      ),
    );
  }
}



