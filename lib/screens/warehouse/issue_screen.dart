import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../services/issue_number_service.dart';
import 'warehouse_nav_notification.dart';
import 'pallet_issue_screen.dart';

class IssueScreen extends StatefulWidget {
  /// When provided, IssueScreen opens in "edit" mode and pre-fills the form from these pending issue lines.
  final List<StockMovement>? editIssues;

  const IssueScreen({super.key, this.editIssues});

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueLine {
  material_model.Material? material;
  int? movementId; // existing stock_movements.id (edit mode)
  bool usePurchasePrice = false;
  final TextEditingController itemTextController = TextEditingController();
  final FocusNode itemFocusNode = FocusNode();
  final TextEditingController quantityController = TextEditingController();

  void dispose() {
    itemTextController.dispose();
    itemFocusNode.dispose();
    quantityController.dispose();
  }
}

class _IssueScreenState extends State<IssueScreen> {
  final _formKey = GlobalKey<FormState>();

  // One issue document contains multiple item lines.
  final List<_IssueLine> _lines = <_IssueLine>[];
  int? _draftId;

  final _documentNumberController = TextEditingController();
  final _recipientController = TextEditingController(); // fallback when no customer selected
  final _reasonController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _issueNumberController = TextEditingController();
  DateTime _issueDate = DateTime.now();
  String _selectedReason = 'vyroba'; // movement type / reason
  List<material_model.Material> _materials = [];
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _loading = true;
  bool _saving = false;
  bool _autoIssueNumber = true;
  bool _isEditing = false;
  bool _appliedEditData = false;
  bool _withoutVat = false;
  bool _usePurchasePriceGlobally = false;
  List<StockMovement> _originalIssues = const [];

  DatabaseProvider? _dbProvider;
  int _seenRevision = -1;
  static const _pagePadding = EdgeInsets.all(12);
  static const _cardPadding = EdgeInsets.all(12);
  static const _gap = SizedBox(height: 10);
  static const _fieldGap = SizedBox(height: 10);

  InputDecoration _denseDecoration({
    required String labelText,
    String? helperText,
    Widget? prefixIcon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  String _fmtMoney(num? v) => NumberFormat.currency(symbol: '€', decimalDigits: 2).format((v ?? 0).toDouble());

  double _unitPriceWithoutVat(material_model.Material m) {
    // Use sale price, fallback to purchase price if sale price is not set
    return m.salePrice ?? m.averagePurchasePriceWithoutVat ?? 0.0;
  }

  double? _purchaseUnitWithoutVat(material_model.Material m) => m.averagePurchasePriceWithoutVat;

  double? _purchaseUnitWithVat(material_model.Material m) => m.averagePurchasePriceWithVat;

  double _vatRate(material_model.Material m) => (m.vatRate ?? 20.0);

  double _unitPriceWithVat(material_model.Material m) {
    final base = _unitPriceWithoutVat(m);
    final vat = _vatRate(m);
    return base * (1 + vat / 100);
  }

  double _effectiveUnitPrice(material_model.Material m, {bool? usePurchasePrice}) {
    final shouldUsePurchasePrice = usePurchasePrice ?? _usePurchasePriceGlobally;
    if (shouldUsePurchasePrice) {
      return _purchaseUnitWithoutVat(m) ?? _unitPriceWithoutVat(m);
    }
    if (_withoutVat) {
      return _unitPriceWithoutVat(m);
    } else {
      return _unitPriceWithVat(m);
    }
  }

  double _effectiveVatRate(material_model.Material m) {
    return _withoutVat ? 0.0 : _vatRate(m);
  }

  String _getPriceDisplayTitle(bool usePurchasePrice) {
    if (_withoutVat) {
      return 'Predaj (bez DPH)';
    }
    if (usePurchasePrice || _usePurchasePriceGlobally) {
      return 'Predaj (nákupná cena)';
    }
    return 'Predaj (cena výdaja)';
  }

  String _getSummaryTitle() {
    if (_withoutVat) {
      return 'Súhrn (bez DPH)';
    }
    if (_usePurchasePriceGlobally) {
      return 'Súhrn (nákupné ceny)';
    }
    bool anyPurchasePrice = _lines.any((l) => l.usePurchasePrice);
    if (anyPurchasePrice) {
      return 'Súhrn (zmiešané ceny)';
    }
    return 'Súhrn';
  }

  String _getSalesDisplayTitle() {
    if (_withoutVat) {
      return 'Predaj (bez DPH)';
    }
    if (_usePurchasePriceGlobally) {
      return 'Predaj (nákupné ceny)';
    }
    return 'Predaj (cena výdaja)';
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double buyTotalWithout = 0;
        double buyTotalWith = 0;
        double totalWithout = 0;
        double totalWith = 0;
        double totalEffective = 0;

        for (final l in _lines) {
          final m = l.material;
          final qty = _parseNumber(l.quantityController.text) ?? 0.0;
          if (m == null || qty <= 0) continue;
          buyTotalWithout += (_purchaseUnitWithoutVat(m) ?? 0) * qty;
          buyTotalWith += (_purchaseUnitWithVat(m) ?? 0) * qty;
          totalWithout += _unitPriceWithoutVat(m) * qty;
          totalWith += _unitPriceWithVat(m) * qty;
          totalEffective += _effectiveUnitPrice(m, usePurchasePrice: l.usePurchasePrice) * qty;
        }

        final buyVat = buyTotalWith - buyTotalWithout;
        final totalVat = totalWith - totalWithout;

        Widget pill(String label, String value, {bool strong = false}) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: strong ? FontWeight.bold : FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return AlertDialog(
          title: Text(_getSummaryTitle(), style: Theme.of(context).textTheme.titleLarge),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nákup', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    pill('Bez DPH', _fmtMoney(buyTotalWithout)),
                    pill('DPH', _fmtMoney(buyVat)),
                    pill('S DPH', _fmtMoney(buyTotalWith), strong: true),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_getSalesDisplayTitle(), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    pill('Bez DPH', _fmtMoney(totalWithout)),
                    if (!_withoutVat) ...[
                      pill('DPH', _fmtMoney(totalVat)),
                      pill('S DPH', _fmtMoney(totalWith), strong: true),
                    ] else ...[
                      pill('Cena spolu', _fmtMoney(totalEffective), strong: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvoriť')),
          ],
        );
      },
    );
  }

  final List<Map<String, String>> _reasons = [
    {'value': 'vyroba', 'label': 'Výroba'},
    {'value': 'predaj', 'label': 'Predaj'},
    {'value': 'spotreba', 'label': 'Spotreba'},
    {'value': 'reklamacia', 'label': 'Reklamácia'},
    {'value': 'interny_presun', 'label': 'Interný presun'},
    {'value': 'likvidacia', 'label': 'Likvidácia'},
    {'value': 'dobropis', 'label': 'Dobropis'},
    {'value': 'ine', 'label': 'Iné'},
  ];

  double? _parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  bool _requiresIntegerQuantity(String unit) {
    final u = unit.toLowerCase().trim();
    return u == 'ks' || u == 'pcs' || u == 'piece' || u == 'pieces';
  }

  String _selectedReasonLabel() {
    return _reasons.firstWhere((r) => r['value'] == _selectedReason)['label']!;
  }

  String? _buildNotes(String? description, String? notes) {
    final desc = description?.trim();
    final n = notes?.trim();
    if ((desc == null || desc.isEmpty) && (n == null || n.isEmpty)) return null;
    if (desc != null && desc.isNotEmpty && (n == null || n.isEmpty)) return desc;
    if ((desc == null || desc.isEmpty) && n != null && n.isNotEmpty) return n;
    return '$desc\n$n';
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.editIssues != null && widget.editIssues!.isNotEmpty;
    if (_isEditing) {
      _originalIssues = List<StockMovement>.from(widget.editIssues!);
    } else {
      _lines.add(_IssueLine());
    }
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = Provider.of<DatabaseProvider>(context);
    if (!identical(_dbProvider, db)) {
      _dbProvider?.removeListener(_onDbChanged);
      _dbProvider = db;
      _seenRevision = db.revision;
      db.addListener(_onDbChanged);
    }
  }

  void _onDbChanged() {
    final db = _dbProvider;
    if (db == null) return;
    if (_seenRevision == db.revision) return;
    _seenRevision = db.revision;
    if (!mounted) return;
    // Silent refresh: re-fetch reference lists without resetting the form.
    _refreshReferenceData();
  }

  Future<void> _refreshReferenceData() async {
    if (_loading) return; // initial load will handle it
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final warehouses = await dbProvider.getWarehouses(activeOnly: true);
    final customers = await dbProvider.getCustomers(activeOnly: true);

    if (!mounted) return;

    final prevWhId = _selectedWarehouse?.id;
    final prevCustId = _selectedCustomer?.id;

    setState(() {
      _materials = materials;
      _warehouses = warehouses;
      _customers = customers;
      _selectedWarehouse = prevWhId == null
          ? (_selectedWarehouse ?? (warehouses.isNotEmpty ? warehouses.first : null))
          : warehouses.where((w) => w.id == prevWhId).cast<Warehouse?>().firstWhere((e) => e != null, orElse: () => _selectedWarehouse);
      _selectedCustomer = prevCustId == null
          ? _selectedCustomer
          : customers.where((c) => c.id == prevCustId).cast<Customer?>().firstWhere((e) => e != null, orElse: () => _selectedCustomer);

      // Update selected materials in lines by id (keeps stock/unit fresh for validation).
      for (final l in _lines) {
        final id = l.material?.id;
        if (id == null) continue;
        final updated = materials.where((m) => m.id == id).cast<material_model.Material?>().firstWhere((e) => e != null, orElse: () => l.material);
        l.material = updated;
      }
    });
  }

  Future<void> _saveDraft() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    final lines = _lines
        .where((l) => l.material != null || l.itemTextController.text.trim().isNotEmpty)
        .map((l) => {
              'material_id': l.material?.id,
              'item_text': l.itemTextController.text.trim(),
              'quantity': l.quantityController.text.trim(),
              'use_purchase_price': l.usePurchasePrice,
            })
        .toList();

    final data = <String, dynamic>{
      'draft_version': 1,
      'issue_date': _issueDate.toIso8601String(),
      'auto_issue_number': _autoIssueNumber,
      'issue_number': _issueNumberController.text.trim(),
      'warehouse_id': _selectedWarehouse?.id,
      'movement_type': _selectedReason,
      'customer_id': _selectedCustomer?.id,
      'document_number': _documentNumberController.text.trim(),
      'recipient_name': _recipientController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _reasonController.text.trim(),
      'notes': _notesController.text.trim(),
      'without_vat': _withoutVat,
      'use_purchase_price_globally': _usePurchasePriceGlobally,
      'lines': lines,
    };

    final title = [
      _issueNumberController.text.trim().isEmpty ? 'Rozpracovaná výdajka' : _issueNumberController.text.trim(),
      _selectedCustomer?.name,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • ');

    final id = await dbProvider.saveDraftDocument(
      id: _draftId,
      docType: 'issue',
      title: title.isEmpty ? null : title,
      data: data,
    );

    if (!mounted) return;
    setState(() => _draftId = id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rozpracovaná výdajka uložená')));
  }

  Future<void> _openDraftPicker() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final drafts = await dbProvider.listDraftDocuments(docType: 'issue');
    if (!mounted) return;

    final pickedId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rozpracované výdajky'),
        content: SizedBox(
          width: 520,
          child: drafts.isEmpty
              ? const Text('Žiadne rozpracované výdajky.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = drafts[i];
                    final title = (d['title'] as String?)?.trim();
                    final updatedAt = d['updated_at'] as String?;
                    return ListTile(
                      title: Text(title == null || title.isEmpty ? 'Rozpracovaná výdajka' : title),
                      subtitle: updatedAt == null ? null : Text('Upravené: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(updatedAt))}'),
                      onTap: () => Navigator.pop(context, d['id'] as int),
                      trailing: IconButton(
                        tooltip: 'Vymazať',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final id = d['id'] as int;
                          await dbProvider.deleteDraftDocument(id);
                          if (!context.mounted) return;
                          Navigator.pop(context, -id);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvoriť')),
        ],
      ),
    );

    if (pickedId == null) return;
    if (pickedId < 0) {
      // deleted one; reopen picker
      await _openDraftPicker();
      return;
    }
    await _loadDraft(pickedId);
  }

  Future<void> _loadDraft(int id) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final row = await dbProvider.getDraftDocument(id);
    if (row == null) return;
    final raw = row['data'] as String;
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final whId = data['warehouse_id'] as int?;
    final custId = data['customer_id'] as int?;
    final reason = (data['movement_type'] as String?) ?? 'vyroba';

    final dateIso = data['issue_date'] as String?;
    final date = dateIso == null ? DateTime.now() : DateTime.parse(dateIso);

    // Replace lines
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();

    final lines = (data['lines'] as List?) ?? const [];
    for (final x in lines) {
      final m = x as Map<String, dynamic>;
      final line = _IssueLine();
      final materialId = m['material_id'] as int?;
      if (materialId != null) {
        line.material = _materials.where((mm) => mm.id == materialId).cast<material_model.Material?>().firstWhere((e) => e != null, orElse: () => null);
      }
      line.itemTextController.text = (m['item_text'] as String?) ?? '';
      line.quantityController.text = (m['quantity'] as String?) ?? '';
      line.usePurchasePrice = (m['use_purchase_price'] as bool?) ?? false;
      _lines.add(line);
    }
    if (_lines.isEmpty) _lines.add(_IssueLine());

    setState(() {
      _draftId = id;
      _issueDate = date;
      _autoIssueNumber = (data['auto_issue_number'] as bool?) ?? true;
      _issueNumberController.text = (data['issue_number'] as String?) ?? '';
      _selectedWarehouse = whId == null ? _selectedWarehouse : _warehouses.where((w) => w.id == whId).cast<Warehouse?>().firstWhere((e) => e != null, orElse: () => _selectedWarehouse);
      _selectedCustomer = custId == null ? null : _customers.where((c) => c.id == custId).cast<Customer?>().firstWhere((e) => e != null, orElse: () => null);
      _selectedReason = reason;
      _documentNumberController.text = (data['document_number'] as String?) ?? '';
      _recipientController.text = (data['recipient_name'] as String?) ?? '';
      _locationController.text = (data['location'] as String?) ?? '';
      _reasonController.text = (data['description'] as String?) ?? '';
      _notesController.text = (data['notes'] as String?) ?? '';
      _withoutVat = (data['without_vat'] as bool?) ?? false;
      _usePurchasePriceGlobally = (data['use_purchase_price_globally'] as bool?) ?? false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rozpracovaná výdajka načítaná')));
  }

  @override
  void dispose() {
    _dbProvider?.removeListener(_onDbChanged);
    for (final l in _lines) {
      l.dispose();
    }
    _documentNumberController.dispose();
    _recipientController.dispose();
    _reasonController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _issueNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final materials = await dbProvider.getMaterials();
    final warehouses = await dbProvider.getWarehouses(activeOnly: true);
    final customers = await dbProvider.getCustomers(activeOnly: true);
    setState(() {
      _materials = materials;
      _warehouses = warehouses;
      _customers = customers;
      _selectedWarehouse = _selectedWarehouse ?? (warehouses.isNotEmpty ? warehouses.first : null);
      _loading = false;
    });
    if (_isEditing && !_appliedEditData && _originalIssues.isNotEmpty) {
      _applyEditIssueData();
    }
  }

  void _applyEditIssueData() {
    if (_appliedEditData || !_isEditing || _originalIssues.isEmpty) return;
    final first = _originalIssues.first;

    // Map stored reason label -> dropdown value.
    final reasonLabel = (first.reason ?? '').trim();
    final match = _reasons.cast<Map<String, String>?>().firstWhere(
          (r) => r?['label']?.trim() == reasonLabel,
          orElse: () => null,
        );
    if (match != null) {
      _selectedReason = match['value']!;
    }

    _autoIssueNumber = false;
    _issueNumberController.text = (first.receiptNumber ?? '').trim();
    _documentNumberController.text = (first.documentNumber ?? '').trim();
    _locationController.text = (first.location ?? '').trim();
    _notesController.text = (first.notes ?? '').trim();
    _issueDate = DateTime.tryParse(first.movementDate) ?? DateTime.now();

    // Header dropdowns by ID.
    if (first.warehouseId != null) {
      _selectedWarehouse = _warehouses.where((w) => w.id == first.warehouseId).cast<Warehouse?>().firstWhere(
            (w) => w != null,
            orElse: () => _selectedWarehouse,
          );
    }
    if (first.customerId != null) {
      _selectedCustomer = _customers.where((c) => c.id == first.customerId).cast<Customer?>().firstWhere(
            (c) => c != null,
            orElse: () => _selectedCustomer,
          );
      _recipientController.text = '';
    } else {
      _selectedCustomer = null;
      _recipientController.text = (first.recipientName ?? '').trim();
    }

    // Build lines.
    final newLines = <_IssueLine>[];
    for (final mvt in _originalIssues) {
      final line = _IssueLine();
      line.movementId = mvt.id;
      final mat = mvt.materialId != null
          ? _materials.cast<material_model.Material?>().firstWhere(
                (x) => x?.id == mvt.materialId,
                orElse: () => null,
              )
          : null;
      if (mat != null) {
        line.material = mat;
        line.itemTextController.text = mat.name;
      } else {
        line.itemTextController.text = '—';
      }
      line.quantityController.text = mvt.quantity.toStringAsFixed(mvt.quantity % 1 == 0 ? 0 : 2);
      newLines.add(line);
    }

    setState(() {
      // Dispose existing lines if any (should be empty in edit mode)
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..addAll(newLines);
      _appliedEditData = true;
    });
  }

  Future<material_model.Material?> _pickItemDialog(BuildContext context) async {
    final searchController = TextEditingController();
    final all = List<material_model.Material>.from(_materials);

    List<material_model.Material> filtered = all;
    material_model.Material? selected;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        void applyFilter() {
          final q = searchController.text.trim().toLowerCase();
          filtered = q.isEmpty
              ? all
              : all.where((m) {
                  final name = m.name.toLowerCase();
                  final type = m.type.toLowerCase();
                  return name.contains(q) || type.contains(q);
                }).toList();
          (ctx as Element).markNeedsBuild();
        }

        return AlertDialog(
          title: const Text('Vyber tovar'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    labelText: 'Hľadať',
                  ),
                  onChanged: (_) => applyFilter(),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = filtered[index];
                      final low = m.currentStock <= m.minStock;
                      return ListTile(
                        dense: true,
                        title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(m.type),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${m.currentStock} ${m.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: low ? Theme.of(context).colorScheme.error : null,
                              ),
                            ),
                            Text(
                              low ? 'Nízky stav' : 'OK',
                              style: TextStyle(
                                fontSize: 11,
                                color: low ? Theme.of(context).colorScheme.error : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          selected = m;
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
          ],
        );
      },
    );

    return selected;
  }

  Future<void> _saveIssue() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    // Extra safety (date picker already blocks future dates)
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    if (_issueDate.isAfter(endOfToday)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Neplatný dátum'),
          content: const Text('Dátum výdaja nesmie byť v budúcnosti.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // Parse & validate lines (extra safety beyond form validators)
    final parsed = <({material_model.Material material, double quantity, int? movementId, bool usePurchasePrice})>[];
    final large = <({material_model.Material material, double quantity, int? movementId, bool usePurchasePrice})>[];

    for (final line in _lines) {
      final material = line.material;
      if (material == null) continue;
      final quantity = _parseNumber(line.quantityController.text) ?? 0;
      if (quantity <= 0) continue;

      if (_requiresIntegerQuantity(material.unit) && quantity % 1 != 0) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Neplatné množstvo'),
            content: Text('Pre ${material.unit} zadajte celé číslo.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }

      if (quantity > material.currentStock) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nedostatok zásob'),
            content: Text(
              'Tovar: ${material.name}\n'
              'Dostupné: ${material.currentStock} ${material.unit}\n'
              'Požadované: $quantity ${material.unit}\n\n'
              'Zadajte menšie množstvo.',
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }

      parsed.add((material: material, quantity: quantity, movementId: line.movementId, usePurchasePrice: line.usePurchasePrice));
      final available = material.currentStock;
      final isLarge = available > 0 && quantity >= available * 0.8;
      if (isLarge) {
        large.add((material: material, quantity: quantity, movementId: line.movementId, usePurchasePrice: line.usePurchasePrice));
      }
    }

    if (parsed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pridajte aspoň jednu položku s množstvom > 0')),
      );
      return;
    }

    // Optional confirmation for large issues (UX safety net).
    if (large.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Potvrdiť výdaj'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Niektoré položky sú veľké (>= 80% dostupných zásob):'),
                const SizedBox(height: 12),
                for (final x in large)
                  Text(
                    '- ${x.material.name}: ${x.quantity} ${x.material.unit} (dostupné ${x.material.currentStock} ${x.material.unit})',
                  ),
                const SizedBox(height: 12),
                const Text('Pokračovať?'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pokračovať')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      await _confirmIssue(parsed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmIssue(List<({material_model.Material material, double quantity, int? movementId, bool usePurchasePrice})> lines) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final reasonLabel = _selectedReasonLabel();

    if (!_isEditing && _autoIssueNumber && _issueNumberController.text.trim().isEmpty) {
      final generated = await IssueNumberService().generateIssueNumber();
      _issueNumberController.text = generated;
    }
    final issueNumber = _issueNumberController.text.trim();
    
    try {
      final docNo = _documentNumberController.text.trim().isEmpty ? null : _documentNumberController.text.trim();
      final location = _locationController.text.trim().isEmpty ? null : _locationController.text.trim();
      final notes = _buildNotes(_reasonController.text, _notesController.text);
      final movementDate = DateFormat('yyyy-MM-dd').format(_issueDate);
      final customerName = _selectedCustomer?.name;
      final recipientName = customerName ??
          (_recipientController.text.trim().isEmpty ? null : _recipientController.text.trim());
      final warehouseId = _selectedWarehouse?.id;
      final customerId = _selectedCustomer?.id;
      final nowIso = DateTime.now().toIso8601String();

      if (_isEditing) {
        // Edit mode: update existing movements, insert new ones, cancel removed ones (keep history).
        final editor = 'Current User'; // TODO: Get from auth
        final originalById = <int, StockMovement>{
          for (final m in _originalIssues)
            if (m.id != null) m.id!: m,
        };
        final usedIds = <int>{};

        for (final line in lines) {
          // Determine pricing mode and get correct price
          String pricingMode = 'sale';
          double unitWithoutVat;
          double vatRate;
          double unitWithVat;
          
          if (_withoutVat) {
            pricingMode = 'vat_exempt';
            unitWithoutVat = _unitPriceWithoutVat(line.material);
            vatRate = 0;
            unitWithVat = unitWithoutVat;
          } else if (line.usePurchasePrice || _usePurchasePriceGlobally) {
            pricingMode = 'purchase';
            unitWithoutVat = _purchaseUnitWithoutVat(line.material) ?? _unitPriceWithoutVat(line.material);
            vatRate = _vatRate(line.material);
            unitWithVat = unitWithoutVat * (1 + vatRate / 100);
          } else {
            unitWithoutVat = _unitPriceWithoutVat(line.material);
            vatRate = _vatRate(line.material);
            unitWithVat = _unitPriceWithVat(line.material);
          }
          
          if (line.movementId != null && originalById.containsKey(line.movementId)) {
            usedIds.add(line.movementId!);
            final original = originalById[line.movementId]!;
            final updated = original.copyWith(
              movementType: 'issue',
              materialId: line.material.id,
              quantity: line.quantity,
              unit: line.material.unit,
              documentNumber: docNo,
              receiptNumber: issueNumber.isEmpty ? null : issueNumber,
              recipientName: recipientName,
              customerId: customerId,
              reason: reasonLabel,
              warehouseId: warehouseId,
              location: location,
              purchasePriceWithoutVat: unitWithoutVat,
              purchasePriceWithVat: unitWithVat,
              vatRate: vatRate,
              pricingMode: pricingMode,
              notes: notes,
              movementDate: movementDate,
              status: 'pending',
              approvedBy: null,
              approvedAt: null,
              rejectionReason: null,
              synced: 0,
              updatedBy: editor,
              updatedAt: nowIso,
            );
            await dbProvider.updateStockMovement(updated);
          } else {
            final movement = StockMovement(
              movementType: 'issue',
              materialId: line.material.id,
              quantity: line.quantity,
              unit: line.material.unit,
              documentNumber: docNo,
              receiptNumber: issueNumber.isEmpty ? null : issueNumber,
              recipientName: recipientName,
              customerId: customerId,
              reason: reasonLabel,
              warehouseId: warehouseId,
              location: location,
              purchasePriceWithoutVat: unitWithoutVat,
              purchasePriceWithVat: unitWithVat,
              vatRate: vatRate,
              pricingMode: pricingMode,
              notes: notes,
              movementDate: movementDate,
              createdBy: editor,
              updatedBy: editor,
              createdAt: nowIso,
              updatedAt: nowIso,
              status: 'pending',
            );
            await dbProvider.insertStockMovement(movement);
          }
        }

        for (final m in _originalIssues) {
          final id = m.id;
          if (id == null) continue;
          if (usedIds.contains(id)) continue;
          final cancelled = m.copyWith(
            status: 'cancelled',
            rejectionReason: 'Odstránené pri editácii',
            approvedBy: editor,
            approvedAt: nowIso,
            updatedBy: editor,
            updatedAt: nowIso,
            synced: 0,
          );
          await dbProvider.updateStockMovement(cancelled);
        }
      } else {
        for (final line in lines) {
          // Determine pricing mode and get correct price
          String pricingMode = 'sale';
          double unitWithoutVat;
          double vatRate;
          double unitWithVat;
          
          if (_withoutVat) {
            pricingMode = 'vat_exempt';
            unitWithoutVat = _unitPriceWithoutVat(line.material);
            vatRate = 0;
            unitWithVat = unitWithoutVat;
          } else if (line.usePurchasePrice || _usePurchasePriceGlobally) {
            pricingMode = 'purchase';
            unitWithoutVat = _purchaseUnitWithoutVat(line.material) ?? _unitPriceWithoutVat(line.material);
            vatRate = _vatRate(line.material);
            unitWithVat = unitWithoutVat * (1 + vatRate / 100);
          } else {
            unitWithoutVat = _unitPriceWithoutVat(line.material);
            vatRate = _vatRate(line.material);
            unitWithVat = _unitPriceWithVat(line.material);
          }
          
          final movement = StockMovement(
            movementType: 'issue',
            materialId: line.material.id,
            quantity: line.quantity,
            unit: line.material.unit,
            documentNumber: docNo,
            receiptNumber: issueNumber.isEmpty ? null : issueNumber,
            recipientName: recipientName,
            customerId: customerId,
            reason: reasonLabel,
            warehouseId: warehouseId,
            location: location,
            purchasePriceWithoutVat: unitWithoutVat,
            purchasePriceWithVat: unitWithVat,
            vatRate: vatRate,
            pricingMode: pricingMode,
            notes: notes,
            movementDate: movementDate,
            createdBy: 'Current User', // TODO: Get from auth
            createdAt: nowIso,
            updatedAt: nowIso,
            status: 'pending',
          );
          await dbProvider.insertStockMovement(movement);
        }
      }
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Výdajka ${issueNumber.isNotEmpty ? issueNumber : ''} upravená (${lines.length} položiek)'
                  : (issueNumber.isNotEmpty
                      ? 'Výdajka $issueNumber uložená na schválenie (${lines.length} položiek)'
                      : 'Výdaj uložený na schválenie (${lines.length} položiek)'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
          ),
        );

        if (_isEditing) {
          Navigator.pop(context);
          return;
        }

        // Clear form
        _documentNumberController.clear();
        _recipientController.clear();
        _reasonController.clear();
        _locationController.clear();
        _notesController.clear();
        _issueNumberController.clear();
        for (final l in _lines) {
          l.dispose();
        }
        _lines
          ..clear()
          ..add(_IssueLine());
        setState(() {
          _selectedReason = 'vyroba';
          _selectedCustomer = null;
          _draftId = null;
        });

        // Jump user to approvals -> issues, as requested.
        const WarehouseNavigateNotification(tabIndex: 1, approvalsMode: 'issue').dispatch(context);
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
            left: 16,
            right: 16,
          ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_draftId == null ? 'Nová výdajka' : 'Rozpracovaná výdajka'),
        actions: [
          IconButton(
            tooltip: 'Výdaj palet (QR sken)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PalletIssueScreen(),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Súhrn',
            onPressed: _showSummaryDialog,
            icon: const Icon(Icons.calculate_outlined),
          ),
          IconButton(
            tooltip: 'Uložiť rozpracované',
            onPressed: _saving ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Otvoriť rozpracované',
            onPressed: _saving ? null : _openDraftPicker,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            Widget section(Widget child) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(padding: _cardPadding, child: child),
                );

            Widget commonInfoSection(Widget child) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: Colors.green.shade50,
                  surfaceTintColor: Colors.green.shade50,
                  child: Padding(padding: _cardPadding, child: child),
                );

            Widget row2(Widget a, Widget b) {
              if (!isWide) return Column(children: [a, _gap, b]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 10),
                  Expanded(child: b),
                ],
              );
            }

            Future<void> generateIssueNumber() async {
              final n = await IssueNumberService().generateIssueNumber();
              if (!context.mounted) return;
              setState(() => _issueNumberController.text = n);
            }

            final dateField = InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _saving
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _issueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _issueDate = date);
                    },
              child: InputDecorator(
                decoration: _denseDecoration(
                  labelText: 'Dátum výdaja *',
                  prefixIcon: const Icon(Icons.event),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(DateFormat('dd.MM.yyyy').format(_issueDate))),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            );

            final issueNumberField = Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _issueNumberController,
                    readOnly: _autoIssueNumber,
                    decoration: _denseDecoration(
                      labelText: 'Číslo výdajky *',
                      helperText: _autoIssueNumber ? 'Vygeneruje sa automaticky' : 'Zadajte ručne',
                      prefixIcon: const Icon(Icons.tag),
                    ),
                    validator: (v) {
                      if (!_autoIssueNumber && (v == null || v.trim().isEmpty)) {
                        return 'Zadajte číslo výdajky';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : generateIssueNumber,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generovať'),
                ),
              ],
            );

            final warehouseField = DropdownButtonFormField<Warehouse?>(
              value: _selectedWarehouse,
              decoration: _denseDecoration(
                labelText: 'Sklad *',
                prefixIcon: const Icon(Icons.warehouse),
              ),
              items: _warehouses
                  .map((w) => DropdownMenuItem<Warehouse?>(value: w, child: Text(w.name)))
                  .toList(),
              onChanged: _saving ? null : (w) => setState(() => _selectedWarehouse = w),
              validator: (v) => v == null ? 'Vyberte sklad' : null,
            );

            final movementTypeField = DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: _denseDecoration(
                labelText: 'Druh pohybu *',
                prefixIcon: const Icon(Icons.category),
              ),
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!)))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _selectedReason = v ?? _selectedReason),
            );

            final customerField = DropdownButtonFormField<Customer?>(
              value: _selectedCustomer,
              decoration: _denseDecoration(
                labelText: 'Zákazník',
                helperText: 'Voliteľné',
                prefixIcon: const Icon(Icons.person),
              ),
              items: [
                const DropdownMenuItem<Customer?>(value: null, child: Text('—')),
                ..._customers.map((c) => DropdownMenuItem<Customer?>(value: c, child: Text(c.name))),
              ],
              onChanged: _saving ? null : (c) => setState(() => _selectedCustomer = c),
            );

            final docField = TextFormField(
              controller: _documentNumberController,
              decoration: _denseDecoration(
                labelText: 'Číslo dokladu',
                helperText: 'Voliteľné',
                prefixIcon: const Icon(Icons.receipt_long),
              ),
              textInputAction: TextInputAction.next,
            );

            final recipientField = TextFormField(
              controller: _recipientController,
              decoration: _denseDecoration(
                labelText: 'Príjemca',
                helperText: 'Použije sa, ak nie je vybraný zákazník',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            );

            final locationField = TextFormField(
              controller: _locationController,
              decoration: _denseDecoration(
                labelText: 'Miesto skladu',
                helperText: 'Voliteľné',
                prefixIcon: const Icon(Icons.location_on),
              ),
              textInputAction: TextInputAction.next,
            );

            final descField = TextFormField(
              controller: _reasonController,
              decoration: _denseDecoration(
                labelText: 'Poznámka / popis',
                helperText: 'Voliteľné',
                prefixIcon: const Icon(Icons.short_text),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            );

            final notesField = TextFormField(
              controller: _notesController,
              decoration: _denseDecoration(
                labelText: 'Interné poznámky',
                prefixIcon: const Icon(Icons.note_alt),
              ),
              maxLines: 3,
            );

            final withoutVatField = SwitchListTile.adaptive(
              value: _withoutVat,
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _withoutVat = v;
                      });
                    },
              title: const Text('Vydaj bez DPH'),
              subtitle: const Text('Pri výpočte ceny nebude zahrnuté DPH'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );

            final purchasePriceField = SwitchListTile.adaptive(
              value: _usePurchasePriceGlobally,
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _usePurchasePriceGlobally = v;
                        if (v) {
                          // Clear individual settings when using global setting
                          for (final line in _lines) {
                            line.usePurchasePrice = false;
                          }
                        }
                      });
                    },
              title: const Text('Vydaj za nákupnú cenu'),
              subtitle: const Text('Použiť nákupnú cenu namiesto predajnej pre všetky položky'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );

            Widget buildLine(_IssueLine line, int idx) {
              String display(material_model.Material m) => '${m.name} (${m.type})';

              final materialField = RawAutocomplete<material_model.Material>(
                textEditingController: line.itemTextController,
                focusNode: line.itemFocusNode,
                displayStringForOption: display,
                optionsBuilder: (TextEditingValue value) {
                  final q = value.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<material_model.Material>.empty();
                  return _materials.where((m) {
                    return m.name.toLowerCase().contains(q) || m.type.toLowerCase().contains(q);
                  }).take(50);
                },
                onSelected: (m) {
                  setState(() => line.material = m);
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _denseDecoration(
                      labelText: idx == 0 ? 'Tovar *' : 'Tovar',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Vybrať zo zoznamu',
                        onPressed: _saving
                            ? null
                            : () async {
                                final picked = await _pickItemDialog(context);
                                if (!context.mounted) return;
                                if (picked != null) {
                                  setState(() => line.material = picked);
                                  controller.text = display(picked);
                                }
                              },
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    onChanged: (_) {
                      final m = line.material;
                      if (m != null && controller.text.trim() != display(m)) {
                        setState(() => line.material = null);
                      }
                    },
                    validator: (_) => line.material == null ? 'Vyberte tovar' : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320, maxWidth: 720),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = options.elementAt(index);
                            final low = m.currentStock <= m.minStock;
                            return ListTile(
                              dense: true,
                              title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(m.type),
                              trailing: Text(
                                '${m.currentStock} ${m.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: low ? Theme.of(context).colorScheme.error : null,
                                ),
                              ),
                              onTap: () => onSelected(m),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );

              final qtyField = TextFormField(
                controller: line.quantityController,
                decoration: _denseDecoration(
                  labelText: 'Množstvo *',
                  prefixIcon: const Icon(Icons.numbers),
                  suffixText: line.material?.unit,
                  helperText: line.material == null
                      ? null
                      : 'Dostupné: ${line.material!.currentStock} ${line.material!.unit}',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  // Recompute per-line totals as the user types.
                  if (mounted) setState(() {});
                },
                validator: (value) {
                  final m = line.material;
                  if (m == null) return 'Vyberte tovar';
                  final parsed = _parseNumber(value);
                  if (parsed == null) return 'Zadajte platné množstvo';
                  if (parsed <= 0) return 'Množstvo musí byť > 0';
                  if (_requiresIntegerQuantity(m.unit) && parsed % 1 != 0) {
                    return 'Pre jednotku "${m.unit}" zadajte celé číslo';
                  }
                  if (parsed > m.currentStock) {
                    return 'Nedostatok zásob (dostupné: ${m.currentStock} ${m.unit})';
                  }
                  return null;
                },
              );

              final mForPrice = line.material;
              final qtyParsed = _parseNumber(line.quantityController.text) ?? 0.0;
              final priceInfo = (mForPrice == null)
                  ? const SizedBox.shrink()
                  : Builder(
                      builder: (context) {
                        final unitWithout = _unitPriceWithoutVat(mForPrice);
                        final vat = _effectiveVatRate(mForPrice);
                        final unitWith = _unitPriceWithVat(mForPrice);
                        final effectiveUnit = _effectiveUnitPrice(mForPrice, usePurchasePrice: line.usePurchasePrice);
                        final totalWithout = unitWithout * qtyParsed;
                        final totalWith = unitWith * qtyParsed;
                        final totalEffective = effectiveUnit * qtyParsed;
                        final totalVat = totalWith - totalWithout;

                        final missingPrice = (mForPrice.salePrice == null);
                        final buyWithout = _purchaseUnitWithoutVat(mForPrice);
                        final buyWith = _purchaseUnitWithVat(mForPrice);
                        final missingBuy = buyWithout == null && buyWith == null;

                        Widget cell(String label, String value, {TextStyle? style}) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              const SizedBox(height: 2),
                              Text(value, style: style ?? const TextStyle(fontSize: 13)),
                            ],
                          );
                        }

                        final warnStyle = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error);

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nákup
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Nákup', style: Theme.of(context).textTheme.labelLarge),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 18,
                                      runSpacing: 10,
                                      children: [
                                        cell('Jedn. bez DPH', missingBuy ? '—' : _fmtMoney(buyWithout)),
                                        cell('Jedn. s DPH', missingBuy ? '—' : _fmtMoney(buyWith)),
                                        if (qtyParsed > 0) ...[
                                          cell('Spolu bez DPH', missingBuy ? '—' : _fmtMoney((buyWithout ?? 0) * qtyParsed)),
                                          cell('Spolu s DPH', missingBuy ? '—' : _fmtMoney((buyWith ?? 0) * qtyParsed)),
                                        ],
                                      ],
                                    ),
                                    if (missingBuy) ...[
                                      const SizedBox(height: 8),
                                      Text('Produkt nemá nastavenú nákupnú cenu (vážený priemer).', style: warnStyle),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Predaj / cena výdaja
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_getPriceDisplayTitle(line.usePurchasePrice), style: Theme.of(context).textTheme.labelLarge),
                                    if (_withoutVat) ...[
                                      const SizedBox(height: 4),
                                      Text('Výdaj oslobodený od DPH', style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w500)),
                                    ] else if (line.usePurchasePrice || _usePurchasePriceGlobally) ...[
                                      const SizedBox(height: 4),
                                      Text('Použitá nákupná cena', style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w500)),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 18,
                                      runSpacing: 10,
                                      children: [
                                        cell('Jedn. bez DPH', _fmtMoney(unitWithout)),
                                        if (!_withoutVat) ...[
                                          cell('DPH %', '${vat.toStringAsFixed(0)}%'),
                                          cell('Jedn. s DPH', _fmtMoney(unitWith)),
                                        ] else ...[
                                          cell('Jedn. cena', _fmtMoney(effectiveUnit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                        if (qtyParsed > 0) ...[
                                          cell('Spolu bez DPH', _fmtMoney(totalWithout)),
                                          if (!_withoutVat) ...[
                                            cell('DPH spolu', _fmtMoney(totalVat)),
                                            cell('Spolu s DPH', _fmtMoney(totalWith), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ] else ...[
                                            cell('Spolu cena', _fmtMoney(totalEffective), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ],
                                      ],
                                    ),
                                    if (missingPrice) ...[
                                      const SizedBox(height: 8),
                                      Text('Produkt nemá nastavenú predajnú cenu.', style: warnStyle),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );

              final removeBtn = IconButton(
                tooltip: 'Odstrániť',
                onPressed: _saving || _lines.length <= 1
                    ? null
                    : () {
                        setState(() {
                          line.dispose();
                          _lines.removeAt(idx);
                        });
                      },
                icon: const Icon(Icons.delete_outline),
              );

              final individualPurchasePriceSwitch = !_usePurchasePriceGlobally && line.material != null
                  ? SwitchListTile.adaptive(
                      value: line.usePurchasePrice,
                      onChanged: _saving
                          ? null
                          : (v) {
                              setState(() {
                                line.usePurchasePrice = v;
                              });
                            },
                      title: const Text('Nákupná cena'),
                      subtitle: const Text('Použiť nákupnú cenu namiesto predajnej'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )
                  : const SizedBox.shrink();

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    materialField,
                    _gap,
                    Row(children: [Expanded(child: qtyField), const SizedBox(width: 8), removeBtn]),
                    individualPurchasePriceSwitch,
                    priceInfo,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: materialField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: qtyField),
                      const SizedBox(width: 6),
                      removeBtn,
                    ],
                  ),
                  individualPurchasePriceSwitch,
                  priceInfo,
                ],
              );
            }

            final saveBtn = Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: isWide ? 280 : double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveIssue,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_saving ? 'Ukladám…' : 'Uložiť na schválenie'),
                ),
              ),
            );

            return ListView(
              padding: _pagePadding,
              children: [
                commonInfoSection(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Spoločné informácie',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      _fieldGap,
                      row2(issueNumberField, dateField),
                      _gap,
                      SwitchListTile.adaptive(
                        value: _autoIssueNumber,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() {
                                  _autoIssueNumber = v;
                                  if (v) _issueNumberController.clear();
                                });
                              },
                        title: const Text('Automaticky generovať číslo výdajky'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      _gap,
                      row2(warehouseField, movementTypeField),
                      _gap,
                      row2(customerField, docField),
                      _gap,
                      row2(recipientField, locationField),
                      _gap,
                      withoutVatField,
                      _gap,
                      purchasePriceField,
                    ],
                  ),
                ),
                _gap,
                Builder(
                  builder: (context) {
                    final itemsCard = section(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list_alt, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Položky',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : () => setState(() => _lines.add(_IssueLine())),
                                icon: const Icon(Icons.add),
                                label: const Text('Pridať položku'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (int i = 0; i < _lines.length; i++) ...[
                            buildLine(_lines[i], i),
                            if (i != _lines.length - 1) const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    );
                    return itemsCard;
                  },
                ),
                _gap,
                section(descField),
                _gap,
                section(notesField),
                const SizedBox(height: 12),
                saveBtn,
              ],
            );
          },
        ),
      ),
    );
  }
}



