import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart';

class QualityTestsScreen extends StatefulWidget {
  final int batchId;

  const QualityTestsScreen({super.key, required this.batchId});

  @override
  State<QualityTestsScreen> createState() => _QualityTestsScreenState();
}

class _QualityTestsScreenState extends State<QualityTestsScreen> {
  List<QualityTest> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final tests = await dbProvider.getQualityTests(widget.batchId);
    setState(() {
      _tests = tests;
      _loading = false;
    });
  }

  Future<void> _addTest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddQualityTestScreen(batchId: widget.batchId),
      ),
    );
    
    if (result == true) {
      _loadTests();
    }
  }

  Future<void> _deleteTest(int testId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vymazať test'),
        content: const Text('Naozaj chcete vymazať tento test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.deleteQualityTest(testId);
      _loadTests();
      
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Test bol vymazaný'),
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalitné testy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTest,
            tooltip: 'Pridať test',
          ),
        ],
      ),
      body: _tests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Žiadne testy',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addTest,
                    icon: const Icon(Icons.add),
                    label: const Text('Pridať prvý test'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tests.length,
              itemBuilder: (context, index) {
                final test = _tests[index];
                return _buildTestCard(test);
              },
            ),
    );
  }

  Widget _buildTestCard(QualityTest test) {
    final testTypeNames = {
      'compression': 'Tlaková pevnosť',
      'density': 'Hustota',
      'absorption': 'Absorpcia vody',
      'frost_resistance': 'Mrazuvzdornosť',
      'dimensions': 'Rozmery',
      'other': 'Iný',
    };

    final testResultColors = {
      'pass': Colors.green,
      'fail': Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testTypeNames[test.testType] ?? test.testType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(
                          DateTime.parse(test.testDate),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (test.testResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: testResultColors[test.testResult]?.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      test.testResult == 'pass' ? 'OK' : 'NOK',
                      style: TextStyle(
                        color: testResultColors[test.testResult]?.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteTest(test.id!),
                ),
              ],
            ),
            if (test.testValue != null) ...[
              const Divider(),
              Row(
                children: [
                  Text(
                    'Hodnota: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${test.testValue!.toStringAsFixed(2)} ${test.testUnit ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (test.testedBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Testoval: ${test.testedBy}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (test.notes != null && test.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  test.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddQualityTestScreen extends StatefulWidget {
  final int batchId;

  const AddQualityTestScreen({super.key, required this.batchId});

  @override
  State<AddQualityTestScreen> createState() => _AddQualityTestScreenState();
}

class _AddQualityTestScreenState extends State<AddQualityTestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedTestType = 'compression';
  final _testValueController = TextEditingController();
  String? _testUnit;
  String? _testResult;
  final _notesController = TextEditingController();
  DateTime _testDate = DateTime.now();

  final Map<String, String> _testTypes = {
    'compression': 'Tlaková pevnosť',
    'density': 'Hustota',
    'absorption': 'Absorpcia vody',
    'frost_resistance': 'Mrazuvzdornosť',
    'dimensions': 'Rozmery',
    'other': 'Iný',
  };

  final Map<String, String> _testUnits = {
    'compression': 'MPa',
    'density': 'kg/m³',
    'absorption': '%',
    'frost_resistance': 'cykly',
    'dimensions': 'mm',
    'other': '',
  };

  @override
  void initState() {
    super.initState();
    _testUnit = _testUnits[_selectedTestType];
  }

  @override
  void dispose() {
    _testValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    final test = QualityTest(
      batchId: widget.batchId,
      testType: _selectedTestType,
      testValue: _testValueController.text.isNotEmpty
          ? double.tryParse(_testValueController.text)
          : null,
      testUnit: _testUnit,
      testResult: _testResult,
      testDate: _testDate.toIso8601String(),
      testedBy: 'Current User', // TODO: Get from auth
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    await dbProvider.insertQualityTest(test);
    
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test bol pridaný'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nový kvalitný test'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Test type
            DropdownButtonFormField<String>(
              value: _selectedTestType,
              decoration: const InputDecoration(
                labelText: 'Typ testu',
                border: OutlineInputBorder(),
              ),
              items: _testTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTestType = value!;
                  _testUnit = _testUnits[value];
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Test date
            ListTile(
              title: const Text('Dátum testu'),
              subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(_testDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _testDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_testDate),
                  );
                  if (time != null) {
                    setState(() {
                      _testDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Test value
            TextFormField(
              controller: _testValueController,
              decoration: InputDecoration(
                labelText: 'Hodnota${_testUnit != null ? ' ($_testUnit)' : ''}',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            // Test result
            DropdownButtonFormField<String>(
              value: _testResult,
              decoration: const InputDecoration(
                labelText: 'Výsledok',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'pass', child: Text('OK')),
                DropdownMenuItem(value: 'fail', child: Text('NOK')),
              ],
              onChanged: (value) {
                setState(() {
                  _testResult = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Poznámky',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Save button
            ElevatedButton(
              onPressed: _saveTest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Uložiť test'),
            ),
          ],
        ),
      ),
    );
  }
}



