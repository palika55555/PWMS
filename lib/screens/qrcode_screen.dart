import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../models/production.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  List<Production> _productions = [];
  Production? _selectedProduction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductions();
  }

  Future<void> _loadProductions() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final productions = await apiService.getProductions();
      setState(() {
        _productions = productions;
        if (productions.isNotEmpty) {
          _selectedProduction = productions.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: $e')),
        );
      }
    }
  }

  Widget _buildQRCodeDisplay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final qrSize = screenSize.width < 600 ? 200.0 : 300.0;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedProduction!.qrCode != null)
                        Image.network(
                          _selectedProduction!.qrCode!,
                          width: qrSize,
                          height: qrSize,
                        )
                      else
                        QrImageView(
                          data: _selectedProduction!.id,
                          size: qrSize,
                          backgroundColor: Colors.white,
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _selectedProduction!.productionTypeName ?? 'Neznámy typ',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Množstvo: ${_selectedProduction!.quantity}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_selectedProduction!.productionDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Dátum: ${_selectedProduction!.productionDate!.day}.${_selectedProduction!.productionDate!.month}.${_selectedProduction!.productionDate!.year}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kód'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Späť',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProductions,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _productions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadna výroba',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vytvorte výrobu pre zobrazenie QR kódu',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Pre malé obrazovky zobrazíme vertikálne
                    if (constraints.maxWidth < 800) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_selectedProduction != null) ...[
                              _buildQRCodeDisplay(context),
                              const Divider(),
                            ],
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Výroba',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _productions.length,
                              itemBuilder: (context, index) {
                                final production = _productions[index];
                                final isSelected =
                                    _selectedProduction?.id == production.id;
                                return ListTile(
                                  selected: isSelected,
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.blue
                                        : Colors.grey[300],
                                    child: Text(
                                      production.quantity.toStringAsFixed(0),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  title: Text(production.productionTypeName ?? 'Neznámy'),
                                  subtitle: Text(
                                    'Množstvo: ${production.quantity}',
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedProduction = production;
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    // Pre väčšie obrazovky zobrazíme horizontálne
                    return Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Výroba',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _productions.length,
                                    itemBuilder: (context, index) {
                                      final production = _productions[index];
                                      final isSelected =
                                          _selectedProduction?.id == production.id;
                                      return ListTile(
                                        selected: isSelected,
                                        leading: CircleAvatar(
                                          backgroundColor: isSelected
                                              ? Colors.blue
                                              : Colors.grey[300],
                                          child: Text(
                                            production.quantity.toStringAsFixed(0),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        title: Text(production.productionTypeName ?? 'Neznámy'),
                                        subtitle: Text(
                                          'Množstvo: ${production.quantity}',
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedProduction = production;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _selectedProduction != null
                              ? _buildQRCodeDisplay(context)
                              : const Center(
                                  child: Text('Vyberte výrobu'),
                                ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
