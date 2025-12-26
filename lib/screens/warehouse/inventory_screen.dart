import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Inventory> _inventories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final inventories = await dbProvider.getInventories();
    setState(() {
      _inventories = inventories;
      _loading = false;
    });
  }

  Future<void> _createInventory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateInventoryScreen(),
      ),
    );
    
    if (result == true) {
      _loadInventories();
    }
  }

  Future<void> _viewInventory(Inventory inventory) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryDetailScreen(inventoryId: inventory.id!),
      ),
    );
    _loadInventories();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventúry'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createInventory,
            tooltip: 'Nová inventúra',
          ),
        ],
      ),
      body: _inventories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Žiadne inventúry',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createInventory,
                    icon: const Icon(Icons.add),
                    label: const Text('Vytvoriť prvú inventúru'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadInventories,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _inventories.length,
                itemBuilder: (context, index) {
                  final inventory = _inventories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: _getStatusIcon(inventory.status),
                      title: Text(
                        'Inventúra ${DateFormat('dd.MM.yyyy').format(DateTime.parse(inventory.inventoryDate))}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stav: ${_getStatusText(inventory.status)}'),
                          if (inventory.location != null)
                            Text('Miesto: ${inventory.location}'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _viewInventory(inventory),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'in_progress':
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      default:
        return const Icon(Icons.event, color: Colors.blue);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Dokončená';
      case 'in_progress':
        return 'Prebieha';
      default:
        return 'Plánovaná';
    }
  }
}

class CreateInventoryScreen extends StatefulWidget {
  const CreateInventoryScreen({super.key});

  @override
  State<CreateInventoryScreen> createState() => _CreateInventoryScreenState();
}

class _CreateInventoryScreenState extends State<CreateInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _inventoryDate = DateTime.now();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createInventory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final inventory = Inventory(
      inventoryDate: DateFormat('yyyy-MM-dd').format(_inventoryDate),
      status: 'planned',
      location: _locationController.text.isEmpty ? null : _locationController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdBy: 'Current User', // TODO: Get from auth
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    try {
      final id = await dbProvider.insertInventory(inventory);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InventoryDetailScreen(inventoryId: id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nová inventúra'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: const Text('Dátum inventúry'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(_inventoryDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _inventoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _inventoryDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Miesto skladu',
                    border: OutlineInputBorder(),
                    helperText: 'Voliteľné',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámky',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createInventory,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Vytvoriť inventúru'),
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryDetailScreen extends StatefulWidget {
  final int inventoryId;

  const InventoryDetailScreen({super.key, required this.inventoryId});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  Inventory? _inventory;
  List<InventoryItem> _items = [];
  List<material_model.Material> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final inventory = await dbProvider.getInventory(widget.inventoryId);
    final items = await dbProvider.getInventoryItems(widget.inventoryId);
    final materials = await dbProvider.getMaterials();
    
    setState(() {
      _inventory = inventory;
      _items = items;
      _materials = materials;
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddInventoryItemDialog(materials: _materials),
    );

    if (result != null) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final material = _materials.firstWhere((m) => m.id == result['material_id']);
      
      final item = InventoryItem(
        inventoryId: widget.inventoryId,
        materialId: result['material_id'] as int,
        recordedQuantity: result['recorded_quantity'] as double,
        actualQuantity: result['actual_quantity'] as double,
        difference: (result['actual_quantity'] as double) - (result['recorded_quantity'] as double),
        unit: material.unit,
        notes: result['notes'] as String?,
        createdAt: DateTime.now().toIso8601String(),
      );

      await dbProvider.insertInventoryItem(item);
      _loadData();
    }
  }

  Future<void> _completeInventory() async {
    if (_inventory == null || _items.isEmpty) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pridajte aspoň jednu položku'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokončiť inventúru'),
        content: const Text('Po dokončení sa automaticky aplikujú úpravy stavov zásob. Pokračovať?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dokončiť'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.applyInventoryAdjustments(widget.inventoryId);
      
      final updatedInventory = Inventory(
        id: _inventory!.id,
        inventoryDate: _inventory!.inventoryDate,
        status: 'completed',
        location: _inventory!.location,
        notes: _inventory!.notes,
        createdBy: _inventory!.createdBy,
        synced: _inventory!.synced,
        createdAt: _inventory!.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await dbProvider.updateInventory(updatedInventory);
      
      _loadData();
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inventúra bola dokončená a úpravy boli aplikované'),
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
  }


  @override
  Widget build(BuildContext context) {
    if (_loading || _inventory == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventúra ${DateFormat('dd.MM.yyyy').format(DateTime.parse(_inventory!.inventoryDate))}'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_inventory!.status != 'completed')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addItem,
              tooltip: 'Pridať položku',
            ),
        ],
      ),
      body: Column(
        children: [
          // Inventory info
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stav: ${_getStatusText(_inventory!.status)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(_inventory!.status),
                        ),
                      ),
                      if (_inventory!.status != 'completed')
                        ElevatedButton.icon(
                          onPressed: _completeInventory,
                          icon: const Icon(Icons.check),
                          label: const Text('Dokončiť'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  if (_inventory!.location != null) ...[
                    const SizedBox(height: 8),
                    Text('Miesto: ${_inventory!.location}'),
                  ],
                ],
              ),
            ),
          ),
          
          // Items list
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Žiadne položky',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Pridať prvú položku'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final material = _materials.firstWhere(
                        (m) => m.id == item.materialId,
                        orElse: () => _materials.first,
                      );
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            material.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Evidované: ${item.recordedQuantity.toStringAsFixed(2)} ${item.unit}'),
                              Text('Skutočné: ${item.actualQuantity.toStringAsFixed(2)} ${item.unit}'),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item.difference > 0
                                  ? Colors.green.shade100
                                  : item.difference < 0
                                      ? Colors.red.shade100
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              item.difference > 0
                                  ? '+${item.difference.toStringAsFixed(2)}'
                                  : item.difference.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.difference > 0
                                    ? Colors.green.shade900
                                    : item.difference < 0
                                        ? Colors.red.shade900
                                        : Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _inventory!.status != 'completed'
          ? FloatingActionButton(
              onPressed: _addItem,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Dokončená';
      case 'in_progress':
        return 'Prebieha';
      default:
        return 'Plánovaná';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class _AddInventoryItemDialog extends StatefulWidget {
  final List<material_model.Material> materials;

  const _AddInventoryItemDialog({required this.materials});

  @override
  State<_AddInventoryItemDialog> createState() => _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<_AddInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  material_model.Material? _selectedMaterial;
  final _recordedController = TextEditingController();
  final _actualController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _recordedController.dispose();
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _add() {
    if (!_formKey.currentState!.validate() || _selectedMaterial == null) {
      return;
    }

    Navigator.pop(context, {
      'material_id': _selectedMaterial!.id,
      'recorded_quantity': double.parse(_recordedController.text),
      'actual_quantity': double.parse(_actualController.text),
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pridať položku do inventúry'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<material_model.Material>(
                value: _selectedMaterial,
                decoration: const InputDecoration(
                  labelText: 'Materiál *',
                  border: OutlineInputBorder(),
                ),
                items: widget.materials.map((material) {
                  return DropdownMenuItem(
                    value: material,
                    child: Text('${material.name} (${material.unit})'),
                  );
                }).toList(),
                onChanged: (material) {
                  setState(() {
                    _selectedMaterial = material;
                    if (material != null) {
                      _recordedController.text = material.currentStock.toStringAsFixed(2);
                    }
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Vyberte materiál';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recordedController,
                decoration: InputDecoration(
                  labelText: 'Evidované množstvo${_selectedMaterial != null ? ' (${_selectedMaterial!.unit})' : ''} *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadajte množstvo';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Zadajte platné množstvo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _actualController,
                decoration: InputDecoration(
                  labelText: 'Skutočné množstvo${_selectedMaterial != null ? ' (${_selectedMaterial!.unit})' : ''} *',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Zadajte množstvo';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Zadajte platné množstvo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Poznámky',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: _add,
          child: const Text('Pridať'),
        ),
      ],
    );
  }
}


