import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/database_provider.dart';
import '../providers/zoom_provider.dart';
import '../widgets/zoom_app_bar.dart';
import 'transport/transport_screen.dart';
import 'production/production_screen.dart';
import 'warehouse/warehouse_screen.dart';
import 'warehouse/material_search_screen.dart';
import 'qr_code/qr_code_screen.dart';

class _DeleteDatabaseIntent extends Intent {
  const _DeleteDatabaseIntent();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyD,
          LogicalKeyboardKey.keyB,
        ): const _DeleteDatabaseIntent(),
      },
      child: Actions(
        actions: {
          _DeleteDatabaseIntent: CallbackAction<_DeleteDatabaseIntent>(
            onInvoke: (_) => _showDeleteDatabaseDialog(context),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
      appBar: ZoomAppBar(
        title: const Text(
          'ProBlock PWMS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<ZoomProvider>(
            builder: (context, zoomProvider, child) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zväčšenie aplikácie (pravý klik na title bar)',
                onSelected: (value) {
                  switch (value) {
                    case 'zoom_in':
                      zoomProvider.zoomIn();
                      break;
                    case 'zoom_out':
                      zoomProvider.zoomOut();
                      break;
                    case 'reset':
                      zoomProvider.resetZoom();
                      break;
                    case 'custom':
                      _showZoomDialog(context, zoomProvider);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'zoom_in',
                    child: const Row(
                      children: [
                        Icon(Icons.zoom_in, size: 20),
                        SizedBox(width: 8),
                        Text('Zväčšiť'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'zoom_out',
                    child: const Row(
                      children: [
                        Icon(Icons.zoom_out, size: 20),
                        SizedBox(width: 8),
                        Text('Zmenšiť'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reset',
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Resetovať (100%)'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'custom',
                    child: const Row(
                      children: [
                        Icon(Icons.tune, size: 20),
                        SizedBox(width: 8),
                        Text('Vlastné zväčšenie...'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Aktuálne: ${(zoomProvider.zoomLevel * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Vitajte v systéme ProBlock',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildMenuCard(
                        context,
                        title: 'Doprava',
                        icon: Icons.local_shipping,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TransportScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        context,
                        title: 'Výroba',
                        icon: Icons.factory,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductionScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        context,
                        title: 'Skladové hospodárstvo',
                        icon: Icons.warehouse,
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WarehouseScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        context,
                        title: 'QR Kód',
                        icon: Icons.qr_code_scanner,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QrCodeScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        context,
                        title: 'Vyhľadávanie',
                        icon: Icons.search,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MaterialSearchScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
          ),
        ),
      ),
    );
  }

  Future<void> _showZoomDialog(BuildContext context, ZoomProvider zoomProvider) async {
    final zoomController = TextEditingController(
      text: (zoomProvider.zoomLevel * 100).toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.zoom_in),
            SizedBox(width: 8),
            Text('Zväčšenie aplikácie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadajte zväčšenie v percentách (50% - 200%):'),
            const SizedBox(height: 16),
            TextField(
              controller: zoomController,
              decoration: const InputDecoration(
                labelText: 'Zväčšenie (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => zoomProvider.setZoomLevel(0.75),
                    icon: const Icon(Icons.zoom_out),
                    label: const Text('75%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => zoomProvider.setZoomLevel(1.0),
                    icon: const Icon(Icons.refresh),
                    label: const Text('100%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => zoomProvider.setZoomLevel(1.25),
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('125%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => zoomProvider.setZoomLevel(1.5),
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('150%'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(zoomController.text);
              if (value != null && value >= 50 && value <= 200) {
                zoomProvider.setZoomLevel(value / 100);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zadajte platnú hodnotu medzi 50 a 200'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Použiť'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDatabaseDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Varovanie'),
          ],
        ),
        content: const Text(
          'Naozaj chcete vymazať všetky údaje z databázy?\n\n'
          'Táto akcia je nezvratná a vymaže všetky materiály, receptúry, šarže, produkty a ostatné údaje.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vymazať databázu'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        await dbProvider.deleteAllData();
        
        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Databáza bola úspešne vymazaná'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba pri vymazávaní databázy: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: color.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


