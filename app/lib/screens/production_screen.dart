import 'package:flutter/material.dart';

import 'batches_screen.dart';
import 'recipes_screen.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Výroba')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _NavCard(
              title: 'Šarže (za deň)',
              body:
                  'Evidencia šarží za daný deň, receptúra, pomery materiálov (cement/štrk frakcie/voda/plastifikátor) a schvaľovanie kvality.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BatchesScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _NavCard(
              title: 'Receptúry',
              body: 'Receptúry na produkty (tvárnice, dlažba, ...).',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RecipesScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _NavCard(
              title: 'Kontrola kvality',
              body:
                  'Záznamy o kontrole kvality šarže + schválenie/neschválenie.',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kontrolu kvality doplníme v ďalšom kroku.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}


