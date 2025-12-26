import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class MovementsHistoryScreen extends StatefulWidget {
  const MovementsHistoryScreen({super.key});

  @override
  State<MovementsHistoryScreen> createState() => _MovementsHistoryScreenState();
}

class _MovementsHistoryScreenState extends State<MovementsHistoryScreen> {
  List<StockMovement> _movements = [];
  List<material_model.Material> _materials = [];
  String? _selectedType;
  int? _selectedMaterialId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = true;

  final List<Map<String, String?>> _movementTypes = [
    {'value': null, 'label': 'Všetky'},
    {'value': 'receipt', 'label': 'Príjem'},
    {'value': 'issue', 'label': 'Výdaj'},
    {'value': 'inventory_adjustment', 'label': 'Inventúra'},
    {'value': 'transfer', 'label': 'Presun'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final movements = await dbProvider.getStockMovements(
      materialId: _selectedMaterialId,
      movementType: _selectedType,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final materials = await dbProvider.getMaterials();
    
    setState(() {
      _movements = movements;
      _materials = materials;
      _loading = false;
    });
  }

  String _getMovementTypeLabel(String type) {
    switch (type) {
      case 'receipt':
        return 'Príjem';
      case 'issue':
        return 'Výdaj';
      case 'inventory_adjustment':
        return 'Inventúra';
      case 'transfer':
        return 'Presun';
      default:
        return type;
    }
  }

  Color _getMovementTypeColor(String type) {
    switch (type) {
      case 'receipt':
        return Colors.green;
      case 'issue':
        return Colors.orange;
      case 'inventory_adjustment':
        return Colors.blue;
      case 'transfer':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMovementTypeIcon(String type) {
    switch (type) {
      case 'receipt':
        return Icons.arrow_downward;
      case 'issue':
        return Icons.arrow_upward;
      case 'inventory_adjustment':
        return Icons.adjust;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.arrow_forward;
    }
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
        title: const Text('História pohybov'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters summary
          if (_selectedType != null || _selectedMaterialId != null || _fromDate != null || _toDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedType != null)
                          Chip(
                            label: Text(_getMovementTypeLabel(_selectedType!)),
                            onDeleted: () {
                              setState(() {
                                _selectedType = null;
                              });
                              _loadData();
                            },
                          ),
                        if (_selectedMaterialId != null)
                          Chip(
                            label: Text(_materials.firstWhere((m) => m.id == _selectedMaterialId).name),
                            onDeleted: () {
                              setState(() {
                                _selectedMaterialId = null;
                              });
                              _loadData();
                            },
                          ),
                        if (_fromDate != null || _toDate != null)
                          Chip(
                            label: Text(
                              '${_fromDate != null ? DateFormat('dd.MM.yyyy').format(_fromDate!) : ''} - ${_toDate != null ? DateFormat('dd.MM.yyyy').format(_toDate!) : ''}',
                            ),
                            onDeleted: () {
                              setState(() {
                                _fromDate = null;
                                _toDate = null;
                              });
                              _loadData();
                            },
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _selectedMaterialId = null;
                        _fromDate = null;
                        _toDate = null;
                      });
                      _loadData();
                    },
                    child: const Text('Zrušiť filtre'),
                  ),
                ],
              ),
            ),
          
          // Movements list
          Expanded(
            child: _movements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Žiadne pohyby',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _movements.length,
                      itemBuilder: (context, index) {
                        final movement = _movements[index];
                        material_model.Material? material;
                        if (movement.materialId != null && _materials.isNotEmpty) {
                          try {
                            material = _materials.firstWhere(
                              (m) => m.id == movement.materialId,
                            );
                          } catch (e) {
                            material = null;
                          }
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getMovementTypeColor(movement.movementType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getMovementTypeIcon(movement.movementType),
                                color: _getMovementTypeColor(movement.movementType),
                              ),
                            ),
                            title: Text(
                              material != null ? material.name : 'Neznámy materiál',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getMovementTypeLabel(movement.movementType)} • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(movement.movementDate))}',
                                ),
                                if (movement.documentNumber != null)
                                  Text('Doklad: ${movement.documentNumber}'),
                                if (movement.supplierName != null)
                                  Text('Dodávateľ: ${movement.supplierName}'),
                                if (movement.recipientName != null)
                                  Text('Príjemca: ${movement.recipientName}'),
                                if (movement.reason != null)
                                  Text('Dôvod: ${movement.reason}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${movement.movementType == 'issue' ? '-' : '+'}${movement.quantity.toStringAsFixed(2)} ${movement.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _getMovementTypeColor(movement.movementType),
                                  ),
                                ),
                              ],
                            ),
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FiltersBottomSheet(
        selectedType: _selectedType,
        selectedMaterialId: _selectedMaterialId,
        fromDate: _fromDate,
        toDate: _toDate,
        materials: _materials,
        movementTypes: _movementTypes,
        onApply: (type, materialId, from, to) {
          setState(() {
            _selectedType = type;
            _selectedMaterialId = materialId;
            _fromDate = from;
            _toDate = to;
          });
          _loadData();
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _FiltersBottomSheet extends StatefulWidget {
  final String? selectedType;
  final int? selectedMaterialId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<material_model.Material> materials;
  final List<Map<String, String?>> movementTypes;
  final Function(String?, int?, DateTime?, DateTime?) onApply;

  const _FiltersBottomSheet({
    required this.selectedType,
    required this.selectedMaterialId,
    required this.fromDate,
    required this.toDate,
    required this.materials,
    required this.movementTypes,
    required this.onApply,
  });

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  late String? _selectedType;
  late int? _selectedMaterialId;
  late DateTime? _fromDate;
  late DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedMaterialId = widget.selectedMaterialId;
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtre',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Typ pohybu',
                border: OutlineInputBorder(),
              ),
              items: widget.movementTypes.map((type) {
                return DropdownMenuItem<String?>(
                  value: type['value'],
                  child: Text(type['label'] ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<material_model.Material>(
            value: _selectedMaterialId != null
                ? widget.materials.firstWhere((m) => m.id == _selectedMaterialId)
                : null,
            decoration: const InputDecoration(
              labelText: 'Materiál',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<material_model.Material>(
                value: null,
                child: Text('Všetky materiály'),
              ),
              ...widget.materials.map((material) {
                return DropdownMenuItem(
                  value: material,
                  child: Text(material.name),
                );
              }).toList(),
            ],
            onChanged: (material) {
              setState(() {
                _selectedMaterialId = material?.id;
              });
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Od dátumu'),
            subtitle: Text(_fromDate != null
                ? DateFormat('dd.MM.yyyy').format(_fromDate!)
                : 'Nie je vybrané'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _fromDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _fromDate = date;
                });
              }
            },
          ),
          ListTile(
            title: const Text('Do dátumu'),
            subtitle: Text(_toDate != null
                ? DateFormat('dd.MM.yyyy').format(_toDate!)
                : 'Nie je vybrané'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _toDate ?? (_fromDate ?? DateTime.now()),
                firstDate: _fromDate ?? DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _toDate = date;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedType = null;
                      _selectedMaterialId = null;
                      _fromDate = null;
                      _toDate = null;
                    });
                  },
                  child: const Text('Vymazať'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_selectedType, _selectedMaterialId, _fromDate, _toDate);
                  },
                  child: const Text('Aplikovať'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

