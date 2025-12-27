import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart' hide Material;
import '../../providers/database_provider.dart';

class PalletDepositsScreen extends StatefulWidget {
  const PalletDepositsScreen({super.key});

  @override
  State<PalletDepositsScreen> createState() => _PalletDepositsScreenState();
}

class _PalletDepositsScreenState extends State<PalletDepositsScreen> {
  List<Customer> _customers = [];
  int? _selectedCustomerId;
  List<PalletMovement> _movements = [];
  double _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepCustomer = true}) async {
    setState(() => _loading = true);
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final customers = await db.getCustomers(activeOnly: true);
    int? selectedId = keepCustomer ? _selectedCustomerId : null;
    if (selectedId != null) {
      final exists = customers.any((c) => c.id == selectedId);
      if (!exists) selectedId = null;
    }
    selectedId ??= customers.isNotEmpty ? customers.first.id : null;

    List<PalletMovement> movements = const [];
    double balance = 0;
    if (selectedId != null) {
      movements = await db.getPalletMovements(customerId: selectedId);
      balance = await db.getCustomerPalletBalance(selectedId);
    }

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _selectedCustomerId = selectedId;
      _movements = movements;
      _balance = balance;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({PalletMovement? existing, String? quickDirection}) async {
    final customerId = _selectedCustomerId;
    if (customerId == null) return;

    final qtyController = TextEditingController(
      text: existing == null ? '' : existing.quantity.toStringAsFixed(existing.quantity % 1 == 0 ? 0 : 2),
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    DateTime date = DateTime.tryParse(existing?.movementDate ?? '') ?? DateTime.now();
    String direction = quickDirection ?? existing?.direction ?? 'issued';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Nový záznam paliet' : 'Upraviť záznam'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'issued', label: Text('Vydané')),
                    ButtonSegment(value: 'returned', label: Text('Vrátené')),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) => direction = s.first,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Počet paliet *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      date = picked;
                      if (context.mounted) (context as Element).markNeedsBuild();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dátum',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(DateFormat('dd.MM.yyyy').format(date)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Poznámka',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;
                if (qty <= 0) return;
                Navigator.pop(context, true);
              },
              child: const Text('Uložiť'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final qty = double.tryParse(qtyController.text.trim().replaceAll(',', '.')) ?? 0;
    final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final nowIso = DateTime.now().toIso8601String();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    if (existing == null) {
      await db.insertPalletMovement(
        PalletMovement(
          customerId: customerId,
          direction: direction,
          quantity: qty,
          movementDate: dateStr,
          notes: notes,
          createdBy: 'Current User', // TODO: Get from auth
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );
    } else {
      await db.updatePalletMovement(
        existing.copyWith(
          direction: direction,
          quantity: qty,
          movementDate: dateStr,
          notes: notes,
          updatedAt: nowIso,
          synced: 0,
        ),
      );
    }

    await _load();
  }

  Future<void> _delete(PalletMovement m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmazať záznam?'),
        content: const Text('Táto operácia je nevratná.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    if (m.id != null) {
      await db.deletePalletMovement(m.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final custId = _selectedCustomerId;
    final selectedCustomer = custId == null
        ? null
        : _customers.cast<Customer?>().firstWhere((c) => c?.id == custId, orElse: () => null);
    final pricePer = selectedCustomer?.palletDepositPrice ?? 0;
    final depositValue = _balance * pricePer;
    final balanceText = _balance.toStringAsFixed(_balance % 1 == 0 ? 0 : 2);
    final balanceColor = _balance > 0 ? Colors.orange.shade700 : (_balance < 0 ? Colors.red.shade700 : Colors.green.shade700);

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Záloha paliet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: custId,
                    items: _customers
                        .where((c) => c.id != null)
                        .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) async {
                      setState(() => _selectedCustomerId = v);
                      await _load();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Zákazník',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: balanceColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: balanceColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: balanceColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Palety u zákazníka', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                '$balanceText ks',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: balanceColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '(vydané − vrátené)',
                                style: TextStyle(color: Colors.grey[700], fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cena zálohy: ${pricePer.toStringAsFixed(2)} €/ks • Hodnota: ${depositValue.toStringAsFixed(2)} €',
                                style: TextStyle(color: Colors.grey[800], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: custId == null ? null : () => _addOrEdit(quickDirection: 'issued'),
                          icon: const Icon(Icons.add),
                          label: const Text('Vydané'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: custId == null ? null : () => _addOrEdit(quickDirection: 'returned'),
                          icon: const Icon(Icons.add),
                          label: const Text('Vrátené'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_movements.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Žiadne záznamy pre vybraného zákazníka.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            )
          else
            ..._movements.map((m) {
              final isIssued = m.direction == 'issued';
              final sign = isIssued ? '+' : '−';
              final color = isIssued ? Colors.orange.shade700 : Colors.green.shade700;
              final date = DateTime.tryParse(m.movementDate);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(isIssued ? Icons.arrow_outward : Icons.assignment_return, color: color),
                  ),
                  title: Text('$sign ${m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2)} ks'),
                  subtitle: Text(
                    [
                      if (date != null) DateFormat('dd.MM.yyyy').format(date),
                      if (m.notes != null && m.notes!.trim().isNotEmpty) m.notes!.trim(),
                    ].join(' • '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') await _addOrEdit(existing: m);
                      if (v == 'delete') await _delete(m);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Upraviť')),
                      PopupMenuItem(value: 'delete', child: Text('Zmazať')),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}


