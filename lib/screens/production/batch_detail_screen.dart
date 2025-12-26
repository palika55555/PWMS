import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import 'batch_materials_screen.dart';
import 'quality_tests_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final int batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  Batch? _batch;
  Recipe? _recipe;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBatch();
  }

  Future<void> _loadBatch() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final batch = await dbProvider.getBatch(widget.batchId);
    if (batch != null) {
      final recipe = await dbProvider.getRecipe(batch.recipeId);
      setState(() {
        _batch = batch;
        _recipe = recipe;
        _loading = false;
      });
    }
  }

  Future<void> _approveBatch() async {
    if (_batch == null) return;

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final updatedBatch = _batch!.copyWith(
      qualityStatus: 'approved',
      qualityApprovedBy: 'Current User', // TODO: Get from auth
      qualityApprovedAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    await dbProvider.updateBatch(updatedBatch);
    _loadBatch();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Šarža bola schválená'),
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

  Future<void> _rejectBatch() async {
    if (_batch == null) return;

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final updatedBatch = _batch!.copyWith(
      qualityStatus: 'rejected',
      updatedAt: DateTime.now().toIso8601String(),
    );

    await dbProvider.updateBatch(updatedBatch);
    _loadBatch();
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Šarža bola zamietnutá'),
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_batch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Šarža')),
        body: const Center(child: Text('Šarža nebola nájdená')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Šarža ${_batch!.batchNumber}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Batch info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informácie o šarži',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  _buildInfoRow('Číslo šarže', _batch!.batchNumber),
                  _buildInfoRow('Dátum výroby', DateFormat('dd.MM.yyyy').format(DateTime.parse(_batch!.productionDate))),
                  _buildInfoRow('Množstvo', '${_batch!.quantity} ks'),
                  _buildInfoRow('Stav', _getStatusText(_batch!.qualityStatus)),
                  if (_recipe != null)
                    _buildInfoRow('Receptúra', _recipe!.name),
                  if (_batch!.productionTemperature != null)
                    _buildInfoRow('Teplota pri výrobe', '${_batch!.productionTemperature!.toStringAsFixed(1)} °C'),
                  if (_batch!.productionHumidity != null)
                    _buildInfoRow('Vlhkosť pri výrobe', '${_batch!.productionHumidity!.toStringAsFixed(1)} %'),
                  if (_batch!.notes != null && _batch!.notes!.isNotEmpty)
                    _buildInfoRow('Poznámky', _batch!.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Drying and curing section
          if (_batch!.dryingDays != null || _batch!.curingStartDate != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.water_drop, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Sušenie a zrenie',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_batch!.dryingDays != null)
                      _buildInfoRow('Doba sušenia', '${_batch!.dryingDays} dní'),
                    if (_batch!.curingStartDate != null) ...[
                      _buildInfoRow(
                        'Začiatok zrenia',
                        DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(_batch!.curingStartDate!)),
                      ),
                      if (_batch!.curingEndDate != null) ...[
                        _buildInfoRow(
                          'Koniec zrenia',
                          DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(_batch!.curingEndDate!)),
                        ),
                        const SizedBox(height: 8),
                        _buildCuringStatus(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Materials section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Materiály',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BatchMaterialsScreen(
                                batchId: _batch!.id!,
                                recipeId: _batch!.recipeId,
                                quantity: _batch!.quantity,
                              ),
                            ),
                          ).then((_) => _loadBatch());
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Upraviť'),
                      ),
                    ],
                  ),
                  const Divider(),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: Provider.of<DatabaseProvider>(context, listen: false)
                        .getBatchMaterials(_batch!.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Žiadne materiály');
                      }
                      
                      final materials = snapshot.data!;
                      return Column(
                        children: [
                          ...materials.take(3).map((bm) {
                            final material = bm['material'] as material_model.Material?;
                            final fraction = bm['fraction'] as Map<String, dynamic>?;
                            final planned = (bm['planned_amount'] as num).toDouble();
                            final actual = bm['actual_amount'] as double?;
                            
                            if (material == null) return const SizedBox.shrink();
                            
                            // Map material types to Slovak names
                            final typeNames = {
                              'cement': 'Cement',
                              'water': 'Voda',
                              'plasticizer': 'Plastifikátor',
                              'aggregate': 'Agregát',
                            };
                            
                            final typeName = typeNames[material.type] ?? material.type;
                            
                            // For cement, water, plasticizer - show type name prominently
                            // For aggregates - show material name with fraction if available
                            final name = (material.type == 'cement' || material.type == 'water' || material.type == 'plasticizer')
                                ? typeName
                                : (fraction != null
                                    ? '${material.name} - ${fraction['fraction_name']}'
                                    : material.name);
                            
                            // Prioritize actual amount if available, otherwise show planned
                            final usedAmount = actual ?? planned;
                            final hasActual = actual != null;
                            final actualValue = actual ?? 0.0;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (hasActual && (actualValue - planned).abs() > 0.01)
                                          Text(
                                            'Plánované: ${planned.toStringAsFixed(2)} ${material.unit}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${usedAmount.toStringAsFixed(2)} ${material.unit}',
                                    style: TextStyle(
                                      color: hasActual
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (materials.length > 3)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BatchMaterialsScreen(
                                      batchId: _batch!.id!,
                                      recipeId: _batch!.recipeId,
                                      quantity: _batch!.quantity,
                                    ),
                                  ),
                                ).then((_) => _loadBatch());
                              },
                              child: Text('Zobraziť všetky (${materials.length})'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Quality tests section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kvalitné testy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QualityTestsScreen(
                                batchId: _batch!.id!,
                              ),
                            ),
                          ).then((_) => _loadBatch());
                        },
                        icon: const Icon(Icons.science),
                        label: const Text('Spravovať'),
                      ),
                    ],
                  ),
                  const Divider(),
                  FutureBuilder<List<QualityTest>>(
                    future: Provider.of<DatabaseProvider>(context, listen: false)
                        .getQualityTests(_batch!.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Žiadne testy');
                      }
                      
                      final tests = snapshot.data!;
                      final passedTests = tests.where((t) => t.testResult == 'pass').length;
                      final failedTests = tests.where((t) => t.testResult == 'fail').length;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (passedTests > 0)
                                Chip(
                                  avatar: const Icon(Icons.check, size: 18, color: Colors.green),
                                  label: Text('$passedTests OK'),
                                  backgroundColor: Colors.green.shade100,
                                ),
                              if (failedTests > 0) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: const Icon(Icons.close, size: 18, color: Colors.red),
                                  label: Text('$failedTests NOK'),
                                  backgroundColor: Colors.red.shade100,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...tests.take(3).map((test) {
                            final testTypeNames = {
                              'compression': 'Tlaková pevnosť',
                              'density': 'Hustota',
                              'absorption': 'Absorpcia vody',
                              'frost_resistance': 'Mrazuvzdornosť',
                              'dimensions': 'Rozmery',
                              'other': 'Iný',
                            };
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      testTypeNames[test.testType] ?? test.testType,
                                    ),
                                  ),
                                  if (test.testValue != null)
                                    Text(
                                      '${test.testValue!.toStringAsFixed(2)} ${test.testUnit ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  if (test.testResult != null)
                                    Icon(
                                      test.testResult == 'pass' ? Icons.check_circle : Icons.cancel,
                                      color: test.testResult == 'pass' ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (tests.length > 3)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QualityTestsScreen(
                                      batchId: _batch!.id!,
                                    ),
                                  ),
                                ).then((_) => _loadBatch());
                              },
                              child: Text('Zobraziť všetky (${tests.length})'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Quality actions
          if (_batch!.qualityStatus == 'pending')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Schválenie kvality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _approveBatch,
                            icon: const Icon(Icons.check),
                            label: const Text('Schváliť'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejectBatch,
                            icon: const Icon(Icons.close),
                            label: const Text('Zamietnuť'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      default:
        return 'Čaká na schválenie';
    }
  }

  Widget _buildCuringStatus() {
    if (_batch!.curingEndDate == null) return const SizedBox.shrink();
    
    final endDate = DateTime.parse(_batch!.curingEndDate!);
    final now = DateTime.now();
    final daysRemaining = endDate.difference(now).inDays;
    final isCompleted = now.isAfter(endDate);
    
    MaterialColor statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Zrenie ukončené';
    } else if (daysRemaining <= 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Zrenie končí dnes';
    } else if (daysRemaining <= 3) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'Zostáva $daysRemaining ${daysRemaining == 1 ? 'deň' : 'dni'}';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.schedule;
      statusText = 'Zostáva $daysRemaining dní';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.shade200),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor.shade900,
              ),
            ),
          ),
          if (!isCompleted && _batch!.curingStartDate != null && _batch!.dryingDays != null)
            Text(
              '${((now.difference(DateTime.parse(_batch!.curingStartDate!)).inDays / _batch!.dryingDays!) * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor.shade700,
              ),
            ),
        ],
      ),
    );
  }
}


