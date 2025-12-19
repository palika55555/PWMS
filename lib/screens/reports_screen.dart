import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'daily';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporty'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vyberte obdobie',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPeriod,
                          decoration: const InputDecoration(
                            labelText: 'Obdobie',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Denný'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Týždenný'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Mesačný'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedPeriod = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Dátum',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              DateFormat('dd.MM.yyyy').format(_selectedDate),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateReport,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.analytics),
                      label: const Text('Vygenerovať report'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_reportData != null) Expanded(child: _buildReportSummary()),
        ],
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final report = await apiService.getReport(
        period: _selectedPeriod,
        date: _selectedDate,
      );
      setState(() {
        _reportData = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri generovaní reportu: $e')),
        );
      }
    }
  }

  Widget _buildReportSummary() {
    if (_reportData == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prehľad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                _buildSummaryRow(
                  'Počet výrob',
                  _reportData!['total_productions']?.toString() ?? '0',
                ),
                _buildSummaryRow(
                  'Celkové množstvo',
                  _reportData!['total_quantity']?.toString() ?? '0',
                ),
                _buildSummaryRow(
                  'Spotreba materiálov',
                  _reportData!['total_material_consumption']?.toString() ?? '0',
                ),
                if (_reportData!['total_cost'] != null)
                  _buildSummaryRow(
                    'Celkové náklady',
                    '${_reportData!['total_cost']} €',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Detailný report'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportDetailScreen(
                    reportData: _reportData!,
                    period: _selectedPeriod,
                    date: _selectedDate,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

