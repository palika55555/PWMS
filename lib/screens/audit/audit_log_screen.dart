import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/audit_log.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditLog> _logs = [];
  String? _selectedEntityType;
  String? _selectedAction;
  bool _loading = true;

  final List<String> _entityTypes = [
    'all',
    'material',
    'batch',
    'stock_movement',
    'supplier',
    'customer',
    'recipe',
  ];

  final List<String> _actions = [
    'all',
    'create',
    'update',
    'delete',
    'view',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final logs = await dbProvider.getAuditLogs(
      entityType: _selectedEntityType == 'all' ? null : _selectedEntityType,
      action: _selectedAction == 'all' ? null : _selectedAction,
    );
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          if (_selectedEntityType != null || _selectedAction != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  if (_selectedEntityType != null)
                    Chip(
                      label: Text('Typ: ${_selectedEntityType}'),
                      onDeleted: () {
                        setState(() {
                          _selectedEntityType = null;
                          _loadLogs();
                        });
                      },
                    ),
                  if (_selectedAction != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('Akcia: ${_selectedAction}'),
                      onDeleted: () {
                        setState(() {
                          _selectedAction = null;
                          _loadLogs();
                        });
                      },
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEntityType = null;
                        _selectedAction = null;
                        _loadLogs();
                      });
                    },
                    child: const Text('Zrušiť filtre'),
                  ),
                ],
              ),
            ),
          
          // Logs list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Žiadne záznamy',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ExpansionTile(
                                leading: Icon(
                                  _getActionIcon(log.action),
                                  color: _getActionColor(log.action),
                                ),
                                title: Text(
                                  '${_getEntityTypeName(log.entityType)} - ${_getActionName(log.action)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log.userName),
                                    Text(
                                      DateFormat('dd.MM.yyyy HH:mm').format(
                                        DateTime.parse(log.createdAt),
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (log.entityId != null)
                                          Text('ID entity: ${log.entityId}'),
                                        if (log.notes != null) ...[
                                          const SizedBox(height: 8),
                                          Text('Poznámky: ${log.notes}'),
                                        ],
                                        if (log.oldValue != null || log.newValue != null) ...[
                                          const SizedBox(height: 12),
                                          const Divider(),
                                          if (log.oldValue != null) ...[
                                            const Text(
                                              'Predchádzajúca hodnota:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                log.oldValue!,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                          if (log.newValue != null) ...[
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Nová hodnota:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                log.newValue!,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    String? newEntityType = _selectedEntityType ?? 'all';
    String? newAction = _selectedAction ?? 'all';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: newEntityType,
              decoration: const InputDecoration(labelText: 'Typ entity'),
              items: _entityTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type == 'all' ? 'Všetky' : type),
                );
              }).toList(),
              onChanged: (value) {
                newEntityType = value;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: newAction,
              decoration: const InputDecoration(labelText: 'Akcia'),
              items: _actions.map((action) {
                return DropdownMenuItem(
                  value: action,
                  child: Text(action == 'all' ? 'Všetky' : action),
                );
              }).toList(),
              onChanged: (value) {
                newAction = value;
              },
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
              setState(() {
                _selectedEntityType = newEntityType == 'all' ? null : newEntityType;
                _selectedAction = newAction == 'all' ? null : newAction;
                _loadLogs();
              });
              Navigator.pop(context);
            },
            child: const Text('Použiť'),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'view':
        return Icons.visibility;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'view':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getActionName(String action) {
    switch (action) {
      case 'create':
        return 'Vytvorenie';
      case 'update':
        return 'Úprava';
      case 'delete':
        return 'Vymazanie';
      case 'view':
        return 'Zobrazenie';
      default:
        return action;
    }
  }

  String _getEntityTypeName(String entityType) {
    switch (entityType) {
      case 'material':
        return 'Materiál';
      case 'batch':
        return 'Šarža';
      case 'stock_movement':
        return 'Pohyb zásob';
      case 'supplier':
        return 'Dodávateľ';
      case 'customer':
        return 'Zákazník';
      case 'recipe':
        return 'Receptúra';
      default:
        return entityType;
    }
  }
}






