import 'package:flutter/material.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Výroba')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            _InfoCard(
              title: 'Šarže (za deň)',
              body:
                  'Tu bude evidencia šarží za daný deň, receptúra, pomery materiálov (cement/štrk frakcie/voda/plastifikátor) a schvaľovanie kvality.',
            ),
            SizedBox(height: 12),
            _InfoCard(
              title: 'Receptúry',
              body: 'Tu budú receptúry na produkty (tvárnice, dlažba, ...).',
            ),
            SizedBox(height: 12),
            _InfoCard(
              title: 'Kontrola kvality',
              body:
                  'Záznamy o kontrole kvality šarže + schválenie/neschválenie.',
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


