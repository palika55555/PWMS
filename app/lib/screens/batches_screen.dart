import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/batch.dart';
import '../models/recipe.dart';
import '../services/api_client.dart';
import '../services/batches_api.dart';
import '../services/recipes_api.dart';
import 'batch_detail_screen.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late final BatchesApi _batchesApi;
  late final RecipesApi _recipesApi;
  late Future<List<Batch>> _future;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _batchesApi = BatchesApi(client);
    _recipesApi = RecipesApi(client);
    _future = _batchesApi.list(date: _formatDate(_selectedDate));
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _batchesApi.list(date: _formatDate(_selectedDate));
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _future = _batchesApi.list(date: _formatDate(_selectedDate));
      });
    }
  }

  Future<void> _create() async {
    final recipes = await _recipesApi.list();
    if (!mounted) return;

    final created = await showModalBottomSheet<Batch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateBatchSheet(
        date: _selectedDate,
        recipes: recipes,
      ),
    );

    if (!mounted) return;
    if (created != null) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Šarže (za deň)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Zmeniť dátum',
            onPressed: _selectDate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Dátum: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    final today = DateTime.now();
                    if (_selectedDate.year != today.year ||
                        _selectedDate.month != today.month ||
                        _selectedDate.day != today.day) {
                      setState(() {
                        _selectedDate = today;
                        _future = _batchesApi.list(date: _formatDate(_selectedDate));
                      });
                    }
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('Dnes'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<Batch>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 24),
                        Center(child: Text('Chyba: ${snapshot.error}')),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tip: nastav `--dart-define=PROBLOCK_API_BASE_URL=...`',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 24),
                        Center(child: Text('Žiadne šarže pre tento deň.')),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final batch = items[index];
                      return ListTile(
                        title: Text(batch.recipeName ?? 'Bez receptúry'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (batch.productName != null)
                              Text(batch.productName!),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _StatusChip(status: batch.status),
                                const SizedBox(width: 8),
                                Text(
                                  batch.notes ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BatchDetailScreen(batchId: batch.id),
                            ),
                          );
                          if (mounted) {
                            await _reload();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey;
      case 'PRODUCED':
        return Colors.blue;
      case 'QC_PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case 'DRAFT':
        return 'Koncept';
      case 'PRODUCED':
        return 'Vyrobené';
      case 'QC_PENDING':
        return 'Čaká na kontrolu';
      case 'APPROVED':
        return 'Schválené';
      case 'REJECTED':
        return 'Zamietnuté';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(context).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          color: _getStatusColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CreateBatchSheet extends StatefulWidget {
  const _CreateBatchSheet({
    required this.date,
    required this.recipes,
  });

  final DateTime date;
  final List<Recipe> recipes;

  @override
  State<_CreateBatchSheet> createState() => _CreateBatchSheetState();
}

class _CreateBatchSheetState extends State<_CreateBatchSheet> {
  String? _recipeId;
  String? _notes;
  bool _saving = false;
  Object? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
      final created = await BatchesApi(ApiClient()).create(
        batchDate: dateStr,
        recipeId: _recipeId,
        notes: _notes?.trim().isEmpty == true ? null : _notes?.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nová šarža',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Dátum: ${DateFormat('dd.MM.yyyy').format(widget.date)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _recipeId,
            decoration: const InputDecoration(
              labelText: 'Receptúra (voliteľné)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— bez receptúry —'),
              ),
              ...widget.recipes.map(
                (r) => DropdownMenuItem<String?>(
                  value: r.id,
                  child: Text(r.name),
                ),
              ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _recipeId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Poznámky (voliteľné)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: !_saving,
            onChanged: (v) => _notes = v,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Chyba: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Vytvoriť'),
          ),
        ],
      ),
    );
  }
}

