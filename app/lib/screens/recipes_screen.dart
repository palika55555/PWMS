import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/recipe.dart';
import '../services/api_client.dart';
import '../services/products_api.dart';
import '../services/recipes_api.dart';
import 'products_screen.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final RecipesApi _recipesApi;
  late final ProductsApi _productsApi;
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _recipesApi = RecipesApi(client);
    _productsApi = ProductsApi(client);
    _future = _recipesApi.list();
  }

  Future<void> _reload() async {
    setState(() => _future = _recipesApi.list());
  }

  Future<void> _openProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProductsScreen()),
    );
  }

  Future<void> _create() async {
    final products = await _productsApi.list();
    if (!mounted) return;
    final created = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateRecipeSheet(products: products),
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
        title: const Text('Receptúry'),
        actions: [
          IconButton(
            tooltip: 'Produkty',
            onPressed: _openProducts,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Recipe>>(
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
                  Center(child: Text('Zatiaľ žiadne receptúry.')),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = items[index];
                return ListTile(
                  title: Text(r.name),
                  subtitle: r.productName == null || r.productName!.isEmpty
                      ? const Text('Bez produktu')
                      : Text(r.productName!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecipeDetailScreen(
                          recipeId: r.id,
                          recipeName: r.name,
                        ),
                      ),
                    );
                    await _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CreateRecipeSheet extends StatefulWidget {
  const _CreateRecipeSheet({required this.products});

  final List<Product> products;

  @override
  State<_CreateRecipeSheet> createState() => _CreateRecipeSheetState();
}

class _CreateRecipeSheetState extends State<_CreateRecipeSheet> {
  final _nameCtrl = TextEditingController();
  String? _productId;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Názov je povinný');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final created = await RecipesApi(ApiClient()).create(
        name: name,
        productId: _productId,
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
            'Nová receptúra',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Názov',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _productId,
            decoration: const InputDecoration(
              labelText: 'Produkt (voliteľné)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— bez produktu —'),
              ),
              ...widget.products.map(
                (p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(p.name),
                ),
              ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _productId = v),
          ),
          if (widget.products.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: Najprv si založ produkty (vpravo hore ikona).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
                : const Text('Uložiť'),
          ),
        ],
      ),
    );
  }
}


