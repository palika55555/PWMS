import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cp.dart';

class PriceOffersListScreen extends StatelessWidget {
  const PriceOffersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vystavené cenové ponuky'),
        actions: [
          IconButton(
            tooltip: 'Nová ponuka',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CpScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: const PriceOffersListContent(),
    );
  }
}

class PriceOffersListContent extends StatefulWidget {
  const PriceOffersListContent({super.key});

  @override
  State<PriceOffersListContent> createState() => _PriceOffersListContentState();
}

class _PriceOffersListContentState extends State<PriceOffersListContent> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    try {
      final directory = Directory('vystavene_cp');
      if (!await directory.exists()) {
        setState(() {
          _offers = [];
          _loading = false;
        });
        return;
      }

      final files = await directory.list().where((entity) => 
        entity is File && entity.path.endsWith('.json')
      ).cast<File>().toList();

      final offers = <Map<String, dynamic>>[];
      
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          
          offers.add({
            'file': file,
            'offerNumber': data['offerNumber'] ?? 'Neznáme',
            'issueDate': data['issueDate'] ?? '',
            'customerName': data['customer']?['name'] ?? 'Neznámy zákazník',
            'totalAmount': _calculateTotal(data),
            'createdAt': data['createdAt'] ?? '',
          });
        } catch (e) {
          // Skip invalid files
        }
      }

      // Sort by creation date (newest first)
      offers.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  double _calculateTotal(Map<String, dynamic> data) {
    try {
      final items = data['items'] as List? ?? [];
      double total = 0;
      
      for (final item in items) {
        final qty = (item['qty'] ?? 0).toDouble();
        final price = (item['unitPrice'] ?? 0).toDouble();
        final fee = (item['additionalFee'] ?? 0).toDouble();
        total += (qty * price) + fee;
      }
      
      final shipping = (data['shipping'] ?? 0).toDouble();
      final otherFees = (data['otherFees'] ?? 0).toDouble();
      final vatRate = (data['vatPercent'] ?? 20).toDouble() / 100;
      final vatExempt = data['vatExempt'] ?? false;
      final deposit = (data['deposit'] ?? 0).toDouble();
      
      total += shipping + otherFees;
      
      if (!vatExempt) {
        total += total * vatRate;
      }
      
      total -= deposit;
      
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    try {
      final file = offer['file'] as File;
      await file.delete();
      await _loadOffers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cenová ponuka bola zmazaná'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri mazaní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    try {
      final file = offer['file'] as File;
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      // Navigate to CP screen with loaded data
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CpScreen(
              initialData: data,
            ),
          ),
        ).then((_) {
          // Refresh list when returning
          _loadOffers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri načítaní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'sk_SK', symbol: '€').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _offers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Žiadne vystavené cenové ponuky',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vytvorte novú cenovú ponuku a uložte ju',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _offers.length,
                itemBuilder: (context, index) {
                  final offer = _offers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        offer['offerNumber'] ?? 'Neznáme',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer['customerName'] ?? 'Neznámy zákazník'),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(offer['createdAt'] ?? ''),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatMoney(offer['totalAmount']?.toDouble() ?? 0),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editOffer(offer),
                                tooltip: 'Upraviť',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteOffer(offer),
                                tooltip: 'Zmazať',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}