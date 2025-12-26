import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/warehouse_closing.dart';

class WarehouseClosingsScreen extends StatefulWidget {
  const WarehouseClosingsScreen({super.key});

  @override
  State<WarehouseClosingsScreen> createState() => _WarehouseClosingsScreenState();
}

class _WarehouseClosingsScreenState extends State<WarehouseClosingsScreen> {
  List<WarehouseClosing> _closings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClosings();
  }

  Future<void> _loadClosings() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final closings = await dbProvider.getWarehouseClosings();
    setState(() {
      _closings = closings;
      _loading = false;
    });
  }

  Future<void> _createClosing() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    
    final closing = WarehouseClosing(
      closingDate: DateFormat('yyyy-MM-dd').format(now),
      periodFrom: DateFormat('yyyy-MM-dd').format(monthStart),
      periodTo: DateFormat('yyyy-MM-dd').format(monthEnd),
      createdBy: 'Current User', // TODO: Get from auth
      createdAt: DateTime.now().toIso8601String(),
    );
    
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await dbProvider.insertWarehouseClosing(closing);
    await _loadClosings();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Skladová uzávierka bola vytvorená'),
          backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skladové uzávierky'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createClosing,
            tooltip: 'Nová uzávierka',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _closings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadne uzávierky',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createClosing,
                        icon: const Icon(Icons.add),
                        label: const Text('Vytvoriť prvú uzávierku'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadClosings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _closings.length,
                    itemBuilder: (context, index) {
                      final closing = _closings[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getStatusColor(closing.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getStatusIcon(closing.status),
                              color: _getStatusColor(closing.status),
                            ),
                          ),
                          title: Text(
                            'Uzávierka ${DateFormat('d. M. yyyy', 'sk_SK').format(DateTime.parse(closing.closingDate))}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Obdobie: ${DateFormat('d. M.', 'sk_SK').format(DateTime.parse(closing.periodFrom))} - ${DateFormat('d. M. yyyy', 'sk_SK').format(DateTime.parse(closing.periodTo))}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stav: ${_getStatusText(closing.status)}',
                                style: TextStyle(
                                  color: _getStatusColor(closing.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to closing detail
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.lock_open;
      case 'closed':
        return Icons.lock;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'open':
        return 'Otvorená';
      case 'closed':
        return 'Uzavretá';
      case 'cancelled':
        return 'Zrušená';
      default:
        return status;
    }
  }
}



