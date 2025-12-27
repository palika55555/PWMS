import 'package:flutter/material.dart' hide Material;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';
import 'bulk_receipt_screen.dart';
import 'issue_screen.dart';
import 'receipt_print_screen.dart';
import 'issue_print_screen.dart';
import 'edit_receipt_screen.dart';

class ReceiptsPendingScreen extends StatefulWidget {
  const ReceiptsPendingScreen({super.key});

  @override
  State<ReceiptsPendingScreen> createState() => ReceiptsPendingScreenState();
}

class ReceiptsPendingScreenState extends State<ReceiptsPendingScreen> {
  String _mode = 'receipt'; // 'receipt' | 'issue'
  List<StockMovement> _receipts = [];
  Map<String, List<StockMovement>> _groupedReceipts = {}; // Grouped by receiptNumber
  List<StockMovement> _issues = [];
  Map<String, List<StockMovement>> _groupedIssues = {}; // Grouped by documentNumber (or single)
  Map<int, material_model.Material> _materials = {};
  Map<int, Supplier> _suppliers = {};
  Map<int, Warehouse> _warehouses = {};
  Map<int, Customer> _customers = {};
  bool _loading = true;
  String _filterStatus = 'pending'; // pending, approved, rejected, cancelled, all
  bool _showQuickReceiptsOnly = false; // Filter for quick receipts

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  /// Programmatically switch between approvals modes.
  void setMode(String mode) {
    if (mode != 'receipt' && mode != 'issue') return;
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _filterStatus = 'pending';
      _showQuickReceiptsOnly = false;
    });
    _loadReceipts();
  }

  // Format purchase price with 4 decimal places for small values
  String _formatPurchasePrice(double? price) {
    if (price == null) return '-';
    if (price == 0) return '0.0000';
    
    // For very small prices (less than 0.01), show 4 decimal places
    if (price < 0.01) {
      return price.toStringAsFixed(4);
    }
    // For normal prices, show 2 decimal places
    return price.toStringAsFixed(2);
  }

  Future<void> _loadReceipts() async {
    setState(() => _loading = true);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final movements = await dbProvider.getStockMovements(
      movementType: _mode,
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    
    final materials = await dbProvider.getMaterials();
    final suppliers = await dbProvider.getSuppliers();
    final warehouses = await dbProvider.getWarehouses(activeOnly: true);
    final customers = await dbProvider.getCustomers(activeOnly: true);
    
    final materialsMap = <int, material_model.Material>{};
    for (final m in materials) {
      if (m.id != null) {
        materialsMap[m.id!] = m;
      }
    }
    
    final suppliersMap = <int, Supplier>{};
    for (final s in suppliers) {
      if (s.id != null) {
        suppliersMap[s.id!] = s;
      }
    }

    final warehousesMap = <int, Warehouse>{};
    for (final w in warehouses) {
      if (w.id != null) {
        warehousesMap[w.id!] = w;
      }
    }

    final customersMap = <int, Customer>{};
    for (final c in customers) {
      if (c.id != null) {
        customersMap[c.id!] = c;
      }
    }
    
    if (_mode == 'receipt') {
      // Filter by quick receipts if needed
      final filteredReceipts = _showQuickReceiptsOnly
          ? movements.where((r) => r.notes == 'Rýchly príjem').toList()
          : movements;

      // Group receipts by receiptNumber
      final groupedReceipts = <String, List<StockMovement>>{};
      for (final receipt in filteredReceipts) {
        // Use receiptNumber if available, otherwise use unique key for single-item receipts
        final key = receipt.receiptNumber ?? 'single_${receipt.id}';
        if (!groupedReceipts.containsKey(key)) {
          groupedReceipts[key] = [];
        }
        groupedReceipts[key]!.add(receipt);
      }

      setState(() {
        _receipts = filteredReceipts;
        _groupedReceipts = groupedReceipts;
        _issues = [];
        _groupedIssues = {};
        _materials = materialsMap;
        _suppliers = suppliersMap;
        _warehouses = warehousesMap;
        _customers = customersMap;
        _loading = false;
      });
      return;
    } else {
      final filteredIssues = movements;

      // Group issues by internal issue number (receipt_number) if present; else by document number; else single.
      final groupedIssues = <String, List<StockMovement>>{};
      for (final issue in filteredIssues) {
        final issueNo = issue.receiptNumber?.trim();
        final doc = issue.documentNumber?.trim();
        final key = (issueNo != null && issueNo.isNotEmpty)
            ? issueNo
            : ((doc != null && doc.isNotEmpty) ? doc : 'single_${issue.id}');
        if (!groupedIssues.containsKey(key)) {
          groupedIssues[key] = [];
        }
        groupedIssues[key]!.add(issue);
      }

      setState(() {
        _issues = filteredIssues;
        _groupedIssues = groupedIssues;
        _receipts = [];
        _groupedReceipts = {};
        _materials = materialsMap;
        _suppliers = suppliersMap;
        _warehouses = warehousesMap;
        _customers = customersMap;
        _loading = false;
      });
      return;
    }
    
    // unreachable
  }

  Future<void> _approveReceipt(String receiptNumber) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final receipts = _groupedReceipts[receiptNumber] ?? [];
    
    // Approve all movements with this receipt number
    for (final receipt in receipts) {
      if (receipt.id != null) {
        await dbProvider.approveStockMovement(receipt.id!, 'Current User'); // TODO: Get from auth
      }
    }
    
    await _loadReceipts();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Príjemka ${receipts.length > 1 ? "(${receipts.length} položiek) " : ""}bola schválená'),
          backgroundColor: Colors.green,
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

  Future<void> _approveIssue(String groupKey) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final issues = _groupedIssues[groupKey] ?? [];

    try {
      for (final issue in issues) {
        if (issue.id != null) {
          await dbProvider.approveStockMovement(issue.id!, 'Current User'); // TODO: Get from auth
        }
      }

      await _loadReceipts();

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Výdaj ${issues.length > 1 ? "(${issues.length} položiek) " : ""}bol schválený'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    } catch (e) {
      await _loadReceipts();
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba pri schválení: $e'),
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

  Future<void> _rejectReceipt(String receiptNumber) async {
    final reasonController = TextEditingController();
    final receipts = _groupedReceipts[receiptNumber] ?? [];
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zamietnuť príjemku${receipts.length > 1 ? " (${receipts.length} položiek)" : ""}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (receipts.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Táto príjemka obsahuje ${receipts.length} položiek. Všetky budú zamietnuté.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Dôvod zamietnutia *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
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
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zamietnuť'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      // Reject all movements with this receipt number
      for (final receipt in receipts) {
        if (receipt.id != null) {
          await dbProvider.rejectStockMovement(receipt.id!, 'Current User', result);
        }
      }
      await _loadReceipts();
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Príjemka${receipts.length > 1 ? " (${receipts.length} položiek) " : " "}bola zamietnutá'),
            backgroundColor: Colors.orange,
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

  Future<void> _rejectIssue(String groupKey) async {
    final reasonController = TextEditingController();
    final issues = _groupedIssues[groupKey] ?? [];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zamietnuť výdaj${issues.length > 1 ? " (${issues.length} položiek)" : ""}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (issues.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tento výdaj obsahuje ${issues.length} položiek. Všetky budú zamietnuté.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Dôvod zamietnutia *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
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
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Zamietnuť'),
          ),
        ],
      ),
    );

    if (result != null) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      for (final issue in issues) {
        if (issue.id != null) {
          await dbProvider.rejectStockMovement(issue.id!, 'Current User', result);
        }
      }
      await _loadReceipts();

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Výdaj${issues.length > 1 ? " (${issues.length} položiek) " : " "}bol zamietnutý'),
            backgroundColor: Colors.orange,
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

  Future<void> _cancelReceipt(String receiptNumber) async {
    final receipts = _groupedReceipts[receiptNumber] ?? [];
    if (receipts.isEmpty) return;
    final receipt = receipts.first; // Use first receipt for status check
    // First warning dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Stornovať príjemku'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Naozaj chcete stornovať túto príjemku?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (receipt.status == 'approved') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Táto príjemka je schválená a tovar je už na sklade.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Táto akcia nemôže byť vrátená späť.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stornovať'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // If approved, ask about stock return
    bool returnStock = false;
    if (receipt.status == 'approved') {
      final stockDecision = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Vrátiť zásoby?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Táto príjemka je schválená. Ako chcete pokračovať?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RadioListTile<bool>(
                  title: const Text('Vrátiť zásoby zo skladu'),
                  subtitle: const Text('Tovar sa odpočíta zo skladu'),
                  value: true,
                  groupValue: returnStock,
                  onChanged: (value) {
                    setState(() {
                      returnStock = value!;
                    });
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Ponechať tovar na sklade'),
                  subtitle: const Text('Tovar zostane na sklade, len príjemka bude stornovaná'),
                  value: false,
                  groupValue: returnStock,
                  onChanged: (value) {
                    setState(() {
                      returnStock = value!;
                    });
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
                onPressed: () => Navigator.pop(context, returnStock),
                child: const Text('Pokračovať'),
              ),
            ],
          ),
        ),
      );

      if (stockDecision == null) return;
      returnStock = stockDecision;
    }

    // Get cancellation reason
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dôvod stornovania'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Dôvod stornovania *',
            border: OutlineInputBorder(),
            helperText: 'Povinné pole',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stornovať'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      // Cancel all movements with this receipt number
      for (final r in receipts) {
        if (r.id != null) {
          await dbProvider.cancelStockMovement(r.id!, 'Current User', reason, returnStock: returnStock);
        }
      }
      await _loadReceipts();

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(returnStock 
                ? 'Príjemka${receipts.length > 1 ? " (${receipts.length} položiek) " : " "}bola stornovaná a zásoby boli vrátené'
                : 'Príjemka${receipts.length > 1 ? " (${receipts.length} položiek) " : " "}bola stornovaná'),
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

  Future<void> _editReceipt(StockMovement receipt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReceiptScreen(receipt: receipt),
      ),
    );
    if (result == true) {
      _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 'receipt' ? 'Príjemky na schválenie' : 'Výdaje na schválenie'),
        actions: [
          if (_mode == 'receipt')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BulkReceiptScreen(),
                  ),
                );
                if (result == true) {
                  _loadReceipts();
                }
              },
              tooltip: 'Nová príjemka',
            ),
        ],
      ),
      body: Column(
        children: [
          // Mode selector
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'receipt', label: Text('Príjemky'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: 'issue', label: Text('Výdaje'), icon: Icon(Icons.arrow_upward)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                final next = s.first;
                if (next == _mode) return;
                setState(() {
                  _mode = next;
                  // Reset receipt-only filter when switching away.
                  if (_mode != 'receipt') _showQuickReceiptsOnly = false;
                });
                _loadReceipts();
              },
            ),
          ),

          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('pending', 'Na schválenie', Colors.orange),
                  const SizedBox(width: 8),
                  _buildFilterChip('approved', 'Schválené', Colors.green),
                  const SizedBox(width: 8),
                  _buildFilterChip('rejected', 'Zamietnuté', Colors.red),
                  const SizedBox(width: 8),
                  _buildFilterChip('cancelled', 'Stornované', Colors.grey),
                  const SizedBox(width: 8),
                  _buildFilterChip('all', 'Všetky', Colors.grey),
                  const SizedBox(width: 8),
                  if (_mode == 'receipt')
                    FilterChip(
                      label: const Text('Rýchle príjmy'),
                      selected: _showQuickReceiptsOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showQuickReceiptsOnly = selected;
                          _loadReceipts();
                        });
                      },
                      avatar: Icon(
                        Icons.flash_on,
                        size: 18,
                        color: _showQuickReceiptsOnly ? Colors.white : Colors.orange,
                      ),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                    ),
                ],
              ),
            ),
          ),
          
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_mode == 'receipt' ? _receipts.isEmpty : _issues.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _mode == 'receipt' ? 'Žiadne príjemky' : 'Žiadne výdaje',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReceipts,
                        child: _mode == 'receipt'
                            ? ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _groupedReceipts.length,
                                itemBuilder: (context, index) {
                                  final receiptNumber = _groupedReceipts.keys.elementAt(index);
                                  final receipts = _groupedReceipts[receiptNumber]!;
                                  final firstReceipt = receipts.first;
                                  final isGrouped = receipts.length > 1;

                                  // Get supplier from first receipt (should be same for all)
                                  final supplier = firstReceipt.supplierId != null ? _suppliers[firstReceipt.supplierId] : null;

                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _getStatusColor(firstReceipt.status),
                                        width: 2,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      leading: Icon(
                                        _getStatusIcon(firstReceipt.status),
                                        color: _getStatusColor(firstReceipt.status),
                                      ),
                                      title: Text(
                                        isGrouped
                                            ? (firstReceipt.receiptNumber ?? 'Hromadný príjem')
                                            : (_materials[firstReceipt.materialId]?.name ?? 'Neznámy materiál'),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isGrouped
                                                ? '${receipts.length} položiek • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(firstReceipt.movementDate))}'
                                                : '${firstReceipt.quantity} ${firstReceipt.unit} • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(firstReceipt.movementDate))}',
                                          ),
                                          if (firstReceipt.receiptNumber != null && isGrouped)
                                            Text(
                                              'Číslo: ${firstReceipt.receiptNumber}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(firstReceipt.status).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getStatusText(firstReceipt.status),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _getStatusColor(firstReceipt.status),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (firstReceipt.receiptNumber != null) ...[
                                                _buildInfoRow('Číslo príjemky', firstReceipt.receiptNumber!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstReceipt.documentNumber != null) ...[
                                                _buildInfoRow('Číslo dokladu', firstReceipt.documentNumber!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstReceipt.supplierName != null) ...[
                                                _buildInfoRow('Dodávateľ', firstReceipt.supplierName!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (supplier != null) ...[
                                                _buildInfoRow('Dodávateľ (ID)', '${supplier.id ?? '-'}'),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstReceipt.location != null) ...[
                                                _buildInfoRow('Miesto', firstReceipt.location!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstReceipt.approvedBy != null) ...[
                                                _buildInfoRow(
                                                  'Schválil',
                                                  '${firstReceipt.approvedBy} ${firstReceipt.approvedAt != null ? '• ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(firstReceipt.approvedAt!))}' : ''}',
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstReceipt.rejectionReason != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: firstReceipt.status == 'cancelled'
                                                        ? Colors.grey.shade100
                                                        : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        firstReceipt.status == 'cancelled'
                                                            ? 'Dôvod storna:'
                                                            : 'Dôvod zamietnutia:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: firstReceipt.status == 'cancelled'
                                                              ? Colors.grey.shade900
                                                              : Colors.red.shade900,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(firstReceipt.rejectionReason!),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],

                                              // Items list for grouped receipts
                                              if (isGrouped) ...[
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Položky príjemky (${receipts.length}):',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...receipts.asMap().entries.map((entry) {
                                                  final idx = entry.key;
                                                  final r = entry.value;
                                                  final mat = r.materialId != null ? _materials[r.materialId] : null;
                                                  return Container(
                                                    margin: EdgeInsets.only(bottom: idx < receipts.length - 1 ? 12 : 0),
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey.shade300),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                        child: Text(
                                                          mat?.name ?? 'Neznámy materiál',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '${r.quantity} ${r.unit}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (r.purchasePriceWithVat != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Cena s DPH: ${_formatPurchasePrice(r.purchasePriceWithVat)} € za ${r.unit}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                  if (r.notes != null && r.notes!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Poznámka: ${r.notes}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }),
                                        ] else ...[
                                          // Single item details
                                          if (firstReceipt.purchasePriceWithVat != null) ...[
                                            _buildInfoRow(
                                              'Cena s DPH',
                                              '${_formatPurchasePrice(firstReceipt.purchasePriceWithVat)} € za ${firstReceipt.unit}',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (firstReceipt.notes != null) ...[
                                            _buildInfoRow('Poznámky', firstReceipt.notes!),
                                            const SizedBox(height: 8),
                                          ],
                                        ],
                                        
                                        const Divider(),
                                        Row(
                                          children: [
                                            if (firstReceipt.status == 'pending') ...[
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _editReceipt(firstReceipt),
                                                  icon: const Icon(Icons.edit),
                                                  label: const Text('Upraviť'),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _approveReceipt(receiptNumber),
                                                  icon: const Icon(Icons.check),
                                                  label: const Text('Schváliť'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _rejectReceipt(receiptNumber),
                                                  icon: const Icon(Icons.close),
                                                  label: const Text('Zamietnuť'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ] else ...[
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _editReceipt(firstReceipt),
                                                  icon: const Icon(Icons.edit),
                                                  label: const Text('Upraviť'),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => ReceiptPrintScreen(
                                                          receipt: firstReceipt,
                                                          material: _materials[firstReceipt.materialId],
                                                          supplier: supplier,
                                                          allReceipts: isGrouped ? receipts : null,
                                                          materialsMap: _materials,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.print),
                                                  label: const Text('Tlačiť'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        // Cancellation section - hidden by default, expandable
                                        if (firstReceipt.status != 'cancelled') ...[
                                          const SizedBox(height: 12),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          ExpansionTile(
                                            leading: Icon(Icons.dangerous, color: Colors.red.shade700, size: 20),
                                            title: Text(
                                              'Nebezpečné operácie',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.red.shade300),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Stornovanie príjemky je nezvratná operácia.',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.red.shade900,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    OutlinedButton.icon(
                                                      onPressed: () => _cancelReceipt(receiptNumber),
                                                      icon: const Icon(Icons.cancel_outlined),
                                                      label: const Text('Stornovať príjemku'),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: Colors.red,
                                                        side: const BorderSide(color: Colors.red),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _groupedIssues.length,
                                itemBuilder: (context, index) {
                                  final groupKey = _groupedIssues.keys.elementAt(index);
                                  final issues = _groupedIssues[groupKey]!;
                                  final firstIssue = issues.first;
                                  final isGrouped = issues.length > 1;
                                  final mat = firstIssue.materialId != null ? _materials[firstIssue.materialId] : null;
                                  final wh = firstIssue.warehouseId != null ? _warehouses[firstIssue.warehouseId] : null;
                                  final cust = firstIssue.customerId != null ? _customers[firstIssue.customerId] : null;
                                  final partnerName = cust?.name ?? firstIssue.recipientName;

                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _getStatusColor(firstIssue.status),
                                        width: 2,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      leading: Icon(
                                        _getStatusIcon(firstIssue.status),
                                        color: _getStatusColor(firstIssue.status),
                                      ),
                                      title: Text(
                                        isGrouped
                                            ? (firstIssue.receiptNumber ?? firstIssue.documentNumber ?? 'Výdaj')
                                            : (mat?.name ?? 'Neznámy materiál'),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isGrouped
                                                ? '${issues.length} položiek • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(firstIssue.movementDate))}'
                                                : '${firstIssue.quantity} ${firstIssue.unit} • ${DateFormat('dd.MM.yyyy').format(DateTime.parse(firstIssue.movementDate))}',
                                          ),
                                          if (wh != null || (partnerName != null && partnerName.trim().isNotEmpty)) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                if (wh != null) 'Sklad: ${wh.name}',
                                                if (partnerName != null && partnerName.trim().isNotEmpty) 'Zákazník: $partnerName',
                                              ].join(' • '),
                                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                            ),
                                          ],
                                          if (firstIssue.receiptNumber != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Výdajka: ${firstIssue.receiptNumber}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                            ),
                                          ],
                                          if (firstIssue.reason != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Dôvod: ${firstIssue.reason}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(firstIssue.status).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(firstIssue.status),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _getStatusColor(firstIssue.status),
                                                fontWeight: FontWeight.bold,
                                              ),
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
                                              if (wh != null) ...[
                                                _buildInfoRow('Sklad', wh.name),
                                                const SizedBox(height: 8),
                                              ],
                                              if (cust != null) ...[
                                                _buildInfoRow('Zákazník', cust.name),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.receiptNumber != null) ...[
                                                _buildInfoRow('Číslo výdajky', firstIssue.receiptNumber!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.documentNumber != null) ...[
                                                _buildInfoRow('Číslo dokladu', firstIssue.documentNumber!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.recipientName != null) ...[
                                                _buildInfoRow('Príjemca', firstIssue.recipientName!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.location != null) ...[
                                                _buildInfoRow('Miesto', firstIssue.location!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.notes != null) ...[
                                                _buildInfoRow('Poznámky', firstIssue.notes!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.approvedBy != null) ...[
                                                _buildInfoRow(
                                                  'Schválil',
                                                  '${firstIssue.approvedBy} ${firstIssue.approvedAt != null ? '• ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(firstIssue.approvedAt!))}' : ''}',
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.updatedBy != null && firstIssue.updatedAt != null) ...[
                                                _buildInfoRow(
                                                  'Upravil',
                                                  '${firstIssue.updatedBy} • ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(firstIssue.updatedAt!))}',
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              if (firstIssue.rejectionReason != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: firstIssue.status == 'cancelled'
                                                        ? Colors.grey.shade100
                                                        : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        firstIssue.status == 'cancelled'
                                                            ? 'Dôvod storna:'
                                                            : 'Dôvod zamietnutia:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: firstIssue.status == 'cancelled'
                                                              ? Colors.grey.shade900
                                                              : Colors.red.shade900,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(firstIssue.rejectionReason!),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],

                                              const Divider(),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => IssuePrintScreen(
                                                          issues: issues,
                                                          materialsMap: _materials,
                                                          warehousesMap: _warehouses,
                                                          customersMap: _customers,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.print),
                                                  label: const Text('Tlačiť PDF'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),

                                              if (isGrouped) ...[
                                                const Divider(),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Položky výdaja (${issues.length}):',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...issues.asMap().entries.map((entry) {
                                                  final idx = entry.key;
                                                  final i = entry.value;
                                                  final m = i.materialId != null ? _materials[i.materialId] : null;
                                                  return Container(
                                                    margin: EdgeInsets.only(bottom: idx < issues.length - 1 ? 12 : 0),
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey.shade300),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            m?.name ?? 'Neznámy materiál',
                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        Text('${i.quantity} ${i.unit}'),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                                const SizedBox(height: 12),
                                              ],

                                              if (firstIssue.status == 'pending') ...[
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => IssueScreen(editIssues: issues),
                                                            ),
                                                          );
                                                        },
                                                        icon: const Icon(Icons.edit),
                                                        label: const Text('Upraviť'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _rejectIssue(groupKey),
                                                        icon: const Icon(Icons.close),
                                                        label: const Text('Zamietnuť'),
                                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: FilledButton.icon(
                                                        onPressed: () => _approveIssue(groupKey),
                                                        icon: const Icon(Icons.check),
                                                        label: const Text('Schváliť'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
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

  Widget _buildFilterChip(String value, String label, Color color) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _loadReceipts();
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Na schválenie';
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      case 'cancelled':
        return 'Stornované';
      default:
        return status;
    }
  }
}



