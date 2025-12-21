import 'package:flutter/material.dart' hide Material;

import '../models/material.dart' as models;
import '../models/recipe_item.dart';
import '../services/api_client.dart';
import '../services/materials_api.dart';
import '../services/recipes_api.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.recipeName,
  });

  final String recipeId;
  final String recipeName;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipesApi _recipesApi;
  late final MaterialsApi _materialsApi;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _recipesApi = RecipesApi(client);
    _materialsApi = MaterialsApi(client);
    _future = _recipesApi.get(widget.recipeId).then((recipe) async {
      // Načítaj detail s items
      final json = await client.getJson('/v1/recipes/${widget.recipeId}');
      return json;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = _recipesApi.get(widget.recipeId).then((recipe) async {
        final json = await ApiClient().getJson('/v1/recipes/${widget.recipeId}');
        return json;
      });
    });
  }

  Future<void> _addMaterial() async {
    final materials = await _materialsApi.list();
    if (!mounted) return;

    models.Material? selectedMaterial;
    final amountCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pridať materiál'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<models.Material>(
                decoration: const InputDecoration(
                  labelText: 'Materiál',
                  border: OutlineInputBorder(),
                ),
                items: materials.map((m) {
                  return DropdownMenuItem<models.Material>(
                    value: m,
                    child: Text(m.displayName),
                  );
                }).toList(),
                onChanged: (m) {
                  setState(() {
                    selectedMaterial = m;
                    if (m != null) {
                      unitCtrl.text = m.unit;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Množstvo',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jednotka',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: selectedMaterial == null ||
                      amountCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Pridať'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedMaterial != null) {
      try {
        await _recipesApi.addRecipeItem(
          widget.recipeId,
          materialId: selectedMaterial!.id,
          amount: double.parse(amountCtrl.text.trim()),
          unit: unitCtrl.text.trim().isEmpty ? 'kg' : unitCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materiál pridaný')),
          );
          await _reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstrániť materiál?'),
        content: const Text('Skutočne chcete odstrániť tento materiál z receptúry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _recipesApi.deleteRecipeItem(widget.recipeId, itemId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materiál odstránený')),
          );
          await _reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Chyba: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          final items = (data['items'] as List<dynamic>? ?? const [])
              .map((e) => RecipeItem.fromJson(e as Map<String, dynamic>))
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Zatiaľ žiadne materiály v receptúre',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: items.map((item) {
                        return ListTile(
                          title: Text(item.materialName),
                          subtitle: Text(item.categoryLabel +
                              (item.materialFraction != null
                                  ? ' (${item.materialFraction})'
                                  : '')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.amount} ${item.unit}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _deleteItem(item.id),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Pridať materiál'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

