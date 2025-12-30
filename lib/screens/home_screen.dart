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
import 'warehouse/product_pallets_screen.dart';
import 'cp.dart';
import 'price_offers_list_screen.dart';
import 'qr_code/qr_code_screen.dart';
import 'settings/settings_screen.dart';
import 'dart:io';
import 'dart:convert';


class _DeleteDatabaseIntent extends Intent {
  const _DeleteDatabaseIntent();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _noteController = TextEditingController();
  List<String> _dailyNotes = [];
  
  @override
  void initState() {
    super.initState();
    _loadDailyNotes();
  }

  Future<void> _loadDailyNotes() async {
    try {
      final file = File('daily_notes.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        setState(() {
          _dailyNotes = List<String>.from(data['notes'] ?? []);
        });
      }
    } catch (e) {
      // Ignore errors, start with empty list
    }
  }

  Future<void> _saveDailyNotes() async {
    try {
      final file = File('daily_notes.json');
      final data = {
        'notes': _dailyNotes,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Handle error silently
    }
  }

  void _addNote() {
    if (_noteController.text.trim().isNotEmpty) {
      setState(() {
        _dailyNotes.insert(0, '${DateTime.now().toString().substring(11, 16)}: ${_noteController.text.trim()}');
        _noteController.clear();
      });
      _saveDailyNotes();
    }
  }

  void _deleteNote(int index) {
    setState(() {
      _dailyNotes.removeAt(index);
    });
    _saveDailyNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Widget _buildDailyNotesCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Poznámky',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _dailyNotes.isEmpty
                  ? Center(
                      child: Text(
                        'Žiadne poznámky',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _dailyNotes.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _dailyNotes[index],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _deleteNote(index),
                            tooltip: 'Vymazať',
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Nová poznámka...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  tooltip: 'Pridať',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Aktuálne: ${(zoomProvider.zoomLevel * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            // -----------------------------
            // Drawer menu
            // -----------------------------
            drawer: _buildDrawer(context),

            body: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Stack(
                children: [
                  // Background logo
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.65,
                      child: Image.asset(
                        'assets/fonts/LOGOOO.png',
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to text logo if image not found
                          return Center(
                            child: Text(
                              'PROBLOCK',
                              style: TextStyle(
                                fontSize: 150,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.count(
                        crossAxisCount: 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 4.0,
                        children: [
                          _buildDailyNotesCard(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // Drawer
  // -----------------------------
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'ProBlock PWMS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildDrawerItem(context,
              icon: Icons.home, title: 'Domov', onTap: () => Navigator.pop(context)),
          _buildDrawerItem(context,
              icon: Icons.local_shipping,
              title: 'Doprava',
              onTap: () => _openScreen(context, const TransportScreen())),
          _buildDrawerItem(context,
              icon: Icons.factory,
              title: 'Výroba',
              onTap: () => _openScreen(context, const ProductionScreen())),
          _buildDrawerItem(context,
              icon: Icons.warehouse,
              title: 'Sklad',
              onTap: () => _openScreen(context, const WarehouseScreen())),
          _buildDrawerItem(context,
              icon: Icons.inventory_2,
              title: 'Palety',
              onTap: () => _openScreen(context, const ProductPalletsScreen())),
          _buildDrawerItem(context,
              icon: Icons.qr_code_scanner,
              title: 'QR Kód',
              onTap: () => _openScreen(context, const QrCodeScreen())),
          _buildDrawerItem(context,
              icon: Icons.search,
              title: 'Vyhľadávanie',
              onTap: () => _openScreen(context, const MaterialSearchScreen())),
          _buildPriceOffersDropdown(context),
          _buildDrawerItem(context,
              icon: Icons.note_alt,
              title: 'Poznámky',
              onTap: () => _showDailyNotesDialog(context)),
          const Divider(),
          _buildDrawerItem(context,
              icon: Icons.settings,
              title: 'Nastavenia',
              onTap: () => _openScreen(context, const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _buildPriceOffersDropdown(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Theme.of(context).splashColor.withOpacity(0.1),
        ),
        child: ExpansionTile(
          leading: const Icon(Icons.request_quote),
          title: const Text('Cenová ponuka'),
          trailing: const Icon(Icons.expand_more),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _openScreen(context, const CpScreen()),
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 18),
                          const SizedBox(width: 12),
                          const Text('Nová ponuka'),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () => _openScreen(context, PriceOffersListScreen()),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, size: 18),
                          const SizedBox(width: 12),
                          const Text('Vystavené ponuky'),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _buildDrawerItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  // -----------------------------
  // Karty v GridView
  // -----------------------------
  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
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
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 24, color: color),
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
              Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.pop(context); // zatvorí drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showDailyNotesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.note_alt, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Poznámky',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _noteController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Zadajte poznámky...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Save notes logic here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Poznámky uložené')),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Uložiť'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      _noteController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Poznámky vymazané')),
                      );
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Vymazať'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // Zoom dialog
  // -----------------------------
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

  // -----------------------------
  // Delete database dialog
  // -----------------------------
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
}
