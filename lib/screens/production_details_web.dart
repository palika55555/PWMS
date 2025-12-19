import 'package:flutter/material.dart';

class ProductionDetailsWeb extends StatelessWidget {
  final Map<String, dynamic>? productionData;

  const ProductionDetailsWeb({
    super.key,
    this.productionData,
  });

  @override
  Widget build(BuildContext context) {
    if (productionData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detaily výroby'),
        ),
        body: const Center(
          child: Text('Žiadne dáta na zobrazenie'),
        ),
      );
    }

    final date = productionData!['date'] as String?;
    final batches = productionData!['batches'] as int? ?? 0;
    final totalQuantity = productionData!['total_quantity'] as int? ?? 0;
    final products = productionData!['products'] as Map<String, dynamic>? ?? {};
    final batchNumbers = productionData!['batch_numbers'] as List? ?? [];

    // Parsovanie dátumu
    DateTime? parsedDate;
    String dateStr = date ?? 'Neznámy dátum';
    if (date != null) {
      try {
        parsedDate = DateTime.parse(date);
        dateStr = '${parsedDate.day.toString().padLeft(2, '0')}.${parsedDate.month.toString().padLeft(2, '0')}.${parsedDate.year}';
      } catch (e) {
        // Ignorovať chybu parsovania
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detaily výroby'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Dátum výroby',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.summarize, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Prehľad',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Počet šarží', '$batches'),
                    const Divider(),
                    _buildInfoRow('Celkom vyrobených', '$totalQuantity ks'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Produkty',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...products.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value} ks',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            if (batchNumbers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Čísla šarží',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: batchNumbers.map((batchNum) {
                          if (batchNum == null) return const SizedBox.shrink();
                          return Chip(
                            label: Text(
                              batchNum.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.purple.shade50,
                            avatar: const Icon(Icons.tag, size: 18),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

