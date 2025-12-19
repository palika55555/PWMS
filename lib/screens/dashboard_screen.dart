import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prehľad'),
        actions: [
          IconButton(
            icon: Icon(apiService.isOnline ? Icons.cloud_done : Icons.cloud_off),
            onPressed: () => apiService.checkConnection(),
            tooltip: apiService.isOnline ? 'Online' : 'Offline',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      apiService.isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: apiService.isOnline ? Colors.green : Colors.red,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apiService.isOnline ? 'Online' : 'Offline',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          apiService.isOnline
                              ? 'Pripojené k serveru'
                              : 'Mimo siete - offline režim',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Rýchle štatistiky',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Produkty',
                    value: '0',
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    title: 'Materiály',
                    value: '0',
                    icon: Icons.category,
                    color: Colors.green,
                  ),
                  _StatCard(
                    title: 'Sklad',
                    value: '0',
                    icon: Icons.warehouse,
                    color: Colors.orange,
                  ),
                  _StatCard(
                    title: 'Výroba',
                    value: '0',
                    icon: Icons.build,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

