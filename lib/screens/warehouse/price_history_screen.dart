import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';

class PriceHistoryScreen extends StatefulWidget {
  final material_model.Material material;
  
  const PriceHistoryScreen({super.key, required this.material});

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  List<PriceHistory> _priceHistory = [];
  List<Supplier> _suppliers = [];
  bool _loading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    setState(() => _loading = true);
    
    try {
      final suppliers = await dbProvider.getSuppliers();
      
      // Load price history for this material
      final priceHistory = await dbProvider.getPriceHistory(
        materialId: widget.material.id,
        supplierId: _selectedSupplierId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      
      setState(() {
        _suppliers = suppliers;
        _priceHistory = priceHistory;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri načítaní histórie cien: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getSupplierName(int? supplierId) {
    if (supplierId == null) return 'Neznámy';
    try {
      return _suppliers.firstWhere((s) => s.id == supplierId).name;
    } catch (e) {
      return 'Neznámy';
    }
  }

  String _formatPrice(double? price) {
    if (price == null) return '-';
    if (price == 0) return '0.00';
    if (price < 0.01) {
      return price.toStringAsFixed(4);
    }
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('História cien: ${widget.material.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filtrovať',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _priceHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Žiadna história cien',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pre tento materiál ešte neboli zaznamenané žiadne ceny',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Súhrn',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Počet záznamov:'),
                              Text(
                                '${_priceHistory.length}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Celkové množstvo:'),
                              Text(
                                '${_priceHistory.fold<double>(0, (sum, p) => sum + p.quantity).toStringAsFixed(2)} ${widget.material.unit}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Priemerná cena bez DPH:'),
                              Text(
                                '${_formatPrice(_priceHistory.fold<double>(0, (sum, p) => sum + p.purchasePriceWithoutVat * p.quantity) / _priceHistory.fold<double>(0, (sum, p) => sum + p.quantity))} €',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Price history list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _priceHistory.length,
                        itemBuilder: (context, index) {
                          final price = _priceHistory[index];
                          final date = DateTime.tryParse(price.priceDate);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          date != null
                                              ? DateFormat('dd.MM.yyyy').format(date)
                                              : price.priceDate,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (price.documentNumber != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            price.documentNumber!,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPriceRow(
                                          'Množstvo',
                                          '${price.quantity.toStringAsFixed(2)} ${widget.material.unit}',
                                          Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPriceRow(
                                          'Dodávateľ',
                                          _getSupplierName(price.supplierId),
                                          Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPriceRow(
                                          'Nákup bez DPH',
                                          '${_formatPrice(price.purchasePriceWithoutVat)} €',
                                          Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPriceRow(
                                          'Nákup s DPH',
                                          '${_formatPrice(price.purchasePriceWithVat)} €',
                                          Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (price.salePrice != null) ...[
                                    const SizedBox(height: 8),
                                    _buildPriceRow(
                                      'Predajná cena',
                                      '${_formatPrice(price.salePrice)} €',
                                      Colors.purple,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'DPH: ${price.vatRate.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Celková hodnota: ${_formatPrice(price.purchasePriceWithVat * price.quantity)} €',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FilterDialog(
        fromDate: _fromDate,
        toDate: _toDate,
        selectedSupplierId: _selectedSupplierId,
        suppliers: _suppliers,
      ),
    );

    if (result != null) {
      setState(() {
        _fromDate = result['fromDate'] as DateTime?;
        _toDate = result['toDate'] as DateTime?;
        _selectedSupplierId = result['supplierId'] as int?;
      });
      await _loadData();
    }
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? selectedSupplierId;
  final List<Supplier> suppliers;

  const _FilterDialog({
    this.fromDate,
    this.toDate,
    this.selectedSupplierId,
    required this.suppliers,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
    _selectedSupplierId = widget.selectedSupplierId;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrovať históriu cien'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Od dátumu'),
              subtitle: Text(
                _fromDate != null
                    ? DateFormat('dd.MM.yyyy').format(_fromDate!)
                    : 'Nevybraté',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context, true),
              ),
              onTap: () => _selectDate(context, true),
            ),
            ListTile(
              title: const Text('Do dátumu'),
              subtitle: Text(
                _toDate != null
                    ? DateFormat('dd.MM.yyyy').format(_toDate!)
                    : 'Nevybraté',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context, false),
              ),
              onTap: () => _selectDate(context, false),
            ),
            ListTile(
              title: const Text('Dodávateľ'),
              subtitle: DropdownButton<int?>(
                value: _selectedSupplierId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Všetci dodávatelia'),
                  ),
                  ...widget.suppliers.map((supplier) => DropdownMenuItem<int?>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedSupplierId = value);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _fromDate = null;
              _toDate = null;
              _selectedSupplierId = null;
            });
          },
          child: const Text('Vymazať filtre'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            {
              'fromDate': _fromDate,
              'toDate': _toDate,
              'supplierId': _selectedSupplierId,
            },
          ),
          child: const Text('Použiť'),
        ),
      ],
    );
  }
}



