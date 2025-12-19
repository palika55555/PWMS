import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final String period;
  final DateTime date;

  const ReportDetailScreen({
    super.key,
    required this.reportData,
    required this.period,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detailný report - ${DateFormat('dd.MM.yyyy').format(date)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prehľad výroby',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  _buildDetailRow('Počet výrob', reportData['total_productions']?.toString() ?? '0'),
                  _buildDetailRow('Celkové množstvo', reportData['total_quantity']?.toString() ?? '0'),
                  if (reportData['total_cost'] != null)
                    _buildDetailRow('Celkové náklady', '${reportData['total_cost']} €'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (reportData['productions'] != null)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Výroby',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ...((reportData['productions'] as List?) ?? []).map((prod) {
                    return ListTile(
                      title: Text(prod['production_type_name'] ?? 'Neznámy typ'),
                      subtitle: Text('Množstvo: ${prod['quantity']}'),
                      trailing: Text(
                        DateFormat('dd.MM.yyyy').format(
                          DateTime.parse(prod['production_date']),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

