import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class ProductionDetailsWeb extends StatefulWidget {
  final Map<String, dynamic>? productionData;

  const ProductionDetailsWeb({
    super.key,
    this.productionData,
  });

  @override
  State<ProductionDetailsWeb> createState() => _ProductionDetailsWebState();
}

class _ProductionDetailsWebState extends State<ProductionDetailsWeb> {
  Map<String, String> _qualityStatuses = {}; // batchNumber -> status
  Map<String, String?> _qualityNotes = {}; // batchNumber -> notes
  Map<String, bool> _shippedStatuses = {}; // batchNumber -> shipped
  Map<String, String?> _shippedDates = {}; // batchNumber -> shippedDate
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Načítať kvalitu a expedovanie asynchrónne po tom, ako sa widget úplne načíta
    Future.microtask(() {
      if (mounted) {
        _loadQualityStatuses();
        _loadShipmentStatuses();
      }
    });
  }

  Future<void> _loadQualityStatuses() async {
    if (!kIsWeb || widget.productionData == null) return;
    
    // Počkať kým sa widget úplne načíta
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final batchNumbers = widget.productionData!['batch_numbers'] as List? ?? [];
      if (batchNumbers.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final baseUrl = html.window.location.origin;
      
      // Načítať kvalitu pre každú šaržu (s timeoutom a error handling)
      for (var batchNum in batchNumbers) {
        if (batchNum == null || !mounted) continue;
        
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/quality?batchNumber=$batchNum'),
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          ).catchError((e) {
            // Ignorovať network chyby
            print('Network error loading quality for $batchNum: $e');
            return http.Response('{"success": false}', 500);
          });

          if (response.statusCode == 200 && mounted) {
            try {
              final data = jsonDecode(response.body);
              if (data['success'] == true && data['quality'] != null) {
                if (mounted) {
                  setState(() {
                    _qualityStatuses[batchNum.toString()] = data['quality']['status'] ?? 'pending';
                    _qualityNotes[batchNum.toString()] = data['quality']['notes'];
                  });
                }
              }
            } catch (e) {
              print('Error parsing quality response for $batchNum: $e');
            }
          }
        } catch (e) {
          // Ignorovať všetky chyby pri načítaní kvality - nie je kritické
          print('Error loading quality for $batchNum: $e');
        }
      }
    } catch (e) {
      // Ignorovať chyby - kvalita nie je kritická pre zobrazenie
      print('Non-critical error loading quality statuses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQualityStatus(String batchNumber, String status, {String? notes}) async {
    if (!kIsWeb || !mounted) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = html.window.location.origin;
      final response = await http.post(
        Uri.parse('$baseUrl/api/quality'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batchNumber': batchNumber,
          'status': status,
          'notes': notes,
          'checkedBy': 'Web User', // V produkcii by to bolo z prihlásenia
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _qualityStatuses[batchNumber] = status;
              _qualityNotes[batchNumber] = notes;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kvalita šarže $batchNumber bola aktualizovaná'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to update quality: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Chyba pri aktualizácii kvality: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showQualityDialog(String batchNumber) {
    final currentStatus = _qualityStatuses[batchNumber] ?? 'pending';
    final currentNotes = _qualityNotes[batchNumber] ?? '';
    final notesController = TextEditingController(text: currentNotes);
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Potvrdiť kvalitu - $batchNumber'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vyberte stav kvality:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text('Schválené'),
                  subtitle: const Text('Výrobok spĺňa požiadavky'),
                  value: 'passed',
                  groupValue: selectedStatus,
                  onChanged: (value) => setDialogState(() => selectedStatus = value!),
                  activeColor: Colors.green,
                ),
                RadioListTile<String>(
                  title: const Text('Varovanie'),
                  subtitle: const Text('Výrobok má menšie nedostatky'),
                  value: 'warning',
                  groupValue: selectedStatus,
                  onChanged: (value) => setDialogState(() => selectedStatus = value!),
                  activeColor: Colors.orange,
                ),
                RadioListTile<String>(
                  title: const Text('Zamietnuté'),
                  subtitle: const Text('Výrobok nespĺňa požiadavky'),
                  value: 'failed',
                  groupValue: selectedStatus,
                  onChanged: (value) => setDialogState(() => selectedStatus = value!),
                  activeColor: Colors.red,
                ),
                RadioListTile<String>(
                  title: const Text('Čaká'),
                  subtitle: const Text('Ešte nebolo skontrolované'),
                  value: 'pending',
                  groupValue: selectedStatus,
                  onChanged: (value) => setDialogState(() => selectedStatus = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Poznámky',
                    hintText: 'Voliteľné poznámky k kontrole kvality',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateQualityStatus(
                  batchNumber,
                  selectedStatus,
                  notes: notesController.text.trim().isEmpty 
                      ? null 
                      : notesController.text.trim(),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Uložiť'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'passed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'passed':
        return 'Schválené';
      case 'failed':
        return 'Zamietnuté';
      case 'warning':
        return 'Varovanie';
      default:
        return 'Čaká';
    }
  }

  Future<void> _loadShipmentStatuses() async {
    if (!kIsWeb || widget.productionData == null) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;

    try {
      final batchNumbers = widget.productionData!['batch_numbers'] as List? ?? [];
      if (batchNumbers.isEmpty) return;

      final baseUrl = html.window.location.origin;
      
      for (var batchNum in batchNumbers) {
        if (batchNum == null || !mounted) continue;
        
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api/shipment?batchNumber=$batchNum'),
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          ).catchError((e) {
            print('Network error loading shipment for $batchNum: $e');
            return http.Response('{"success": false}', 500);
          });

          if (response.statusCode == 200 && mounted) {
            try {
              final data = jsonDecode(response.body);
              if (data['success'] == true && data['shipment'] != null) {
                if (mounted) {
                  setState(() {
                    _shippedStatuses[batchNum.toString()] = data['shipment']['shipped'] ?? false;
                    _shippedDates[batchNum.toString()] = data['shipment']['shippedDate'];
                  });
                }
              }
            } catch (e) {
              print('Error parsing shipment response for $batchNum: $e');
            }
          }
        } catch (e) {
          print('Error loading shipment for $batchNum: $e');
        }
      }
    } catch (e) {
      print('Non-critical error loading shipment statuses: $e');
    }
  }

  Future<void> _updateShipmentStatus(String batchNumber, bool shipped, {String? notes}) async {
    if (!kIsWeb || !mounted) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = html.window.location.origin;
      final response = await http.post(
        Uri.parse('$baseUrl/api/shipment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batchNumber': batchNumber,
          'shipped': shipped,
          'shippedBy': 'Web User',
          'notes': notes,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      ).catchError((e) {
        print('Network error updating shipment: $e');
        return http.Response('{"success": false}', 500);
      });

      if (response.statusCode == 200 && mounted) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              setState(() {
                _shippedStatuses[batchNumber] = shipped;
                _shippedDates[batchNumber] = data['data']?['shippedDate'];
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(shipped 
                      ? 'Šarža $batchNumber bola expedovaná' 
                      : 'Expedovanie šarže $batchNumber bolo zrušené'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          print('Error parsing shipment response: $e');
        }
      } else {
        throw Exception('Failed to update shipment: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Chyba pri aktualizácii expedovania: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showShipmentDialog(String batchNumber, bool isShipped) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isShipped ? 'Zrušiť expedovanie' : 'Expedovať šaržu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isShipped 
                    ? 'Naozaj chcete zrušiť expedovanie šarže $batchNumber?'
                    : 'Naozaj chcete expedovať šaržu $batchNumber?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Poznámky (voliteľné)',
                  hintText: 'Napríklad: Adresa doručenia, dopravca...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateShipmentStatus(
                batchNumber,
                !isShipped,
                notes: notesController.text.trim().isEmpty 
                    ? null 
                    : notesController.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isShipped ? Colors.grey : Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: Text(isShipped ? 'Zrušiť expedovanie' : 'Expedovať'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productionData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detaily výroby'),
        ),
        body: const Center(
          child: Text('Žiadne dáta na zobrazenie'),
        ),
      );
    }

    // Debug: vypísať dostupné kľúče
    print('Production data keys: ${widget.productionData!.keys}');
    print('Production data: ${widget.productionData}');

    final date = widget.productionData!['date'] as String?;
    final batches = widget.productionData!['batches'] as int? ?? 0;
    final totalQuantity = widget.productionData!['total_quantity'] as int? ?? 0;
    final products = widget.productionData!['products'] as Map<String, dynamic>? ?? {};
    final batchNumbers = widget.productionData!['batch_numbers'] as List? ?? [];
    
    print('Parsed data - date: $date, batches: $batches, totalQuantity: $totalQuantity, products: $products, batchNumbers: $batchNumbers');

    // Parsovanie dátumu
    DateTime? parsedDate;
    String dateStr = date ?? 'Neznámy dátum';
    if (date != null) {
      try {
        parsedDate = DateTime.parse(date);
        dateStr = '${parsedDate.day.toString().padLeft(2, '0')}.${parsedDate.month.toString().padLeft(2, '0')}.${parsedDate.year}';
      } catch (e) {
        // Ignorovať chybu parsovania
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detaily výroby'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Dátum výroby',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.summarize, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Prehľad',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Počet šarží', '$batches'),
                    const Divider(),
                    _buildInfoRow('Celkom vyrobených', '$totalQuantity ks'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Produkty',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...products.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value} ks',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            if (batchNumbers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Čísla šarží',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: batchNumbers.map((batchNum) {
                          if (batchNum == null) return const SizedBox.shrink();
                          final batchStr = batchNum.toString();
                          final status = _qualityStatuses[batchStr] ?? 'pending';
                          final statusColor = _getStatusColor(status);
                          
                          return InkWell(
                            onTap: () => _showQualityDialog(batchStr),
                            child: Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    batchStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusLabel(status),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.purple.shade50,
                              avatar: const Icon(Icons.tag, size: 18),
                              deleteIcon: _isLoading 
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.edit, size: 18),
                              onDeleted: () => _showQualityDialog(batchStr),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            // Sekcia pre expedovanie
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Expedovanie',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (batchNumbers.isEmpty)
                      const Text('Žiadne šarže na expedovanie')
                    else ...[
                      ...batchNumbers.map((batchNum) {
                        if (batchNum == null) return const SizedBox.shrink();
                        final batchStr = batchNum.toString();
                        final isShipped = _shippedStatuses[batchStr] ?? false;
                        final shippedDate = _shippedDates[batchStr];
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      isShipped ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isShipped ? Colors.green : Colors.grey,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            batchStr,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              decoration: isShipped 
                                                  ? TextDecoration.lineThrough 
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                          if (isShipped && shippedDate != null)
                                            Text(
                                              'Expedované: ${_formatDate(shippedDate)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isLoading 
                                    ? null 
                                    : () => _showShipmentDialog(batchStr, isShipped),
                                icon: Icon(isShipped ? Icons.undo : Icons.local_shipping),
                                label: Text(isShipped ? 'Zrušiť' : 'Expedovať'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isShipped ? Colors.grey : Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

