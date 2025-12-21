import 'package:flutter/material.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sklad')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            _InfoCard(
              title: 'Materiály',
              body:
                  'Tu budú skladové položky (cement, voda, plastifikátor, štrky podľa frakcie) + aktuálne množstvá.',
            ),
            SizedBox(height: 12),
            _InfoCard(
              title: 'Upozornenia',
              body:
                  'Pri poklese pod minimálnu zásobu sa zobrazí upozornenie (offline aj online).',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}


