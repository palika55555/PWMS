import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../services/products_api.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsApi _api;
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _api = ProductsApi(ApiClient());
    _future = _api.list();
  }

  Future<void> _reload() async {
    setState(() => _future = _api.list());
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateProductSheet(),
    );
    if (!mounted) return;
    if (created != null) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produkty')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Product>>(
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
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 24),
                  Center(child: Text('Zatiaľ žiadne produkty.')),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = items[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: p.description == null || p.description!.isEmpty
                      ? null
                      : Text(p.description!),
                  trailing: p.active
                      ? const Icon(Icons.check_circle_outline)
                      : const Icon(Icons.block),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CreateProductSheet extends StatefulWidget {
  const _CreateProductSheet();

  @override
  State<_CreateProductSheet> createState() => _CreateProductSheetState();
}

class _CreateProductSheetState extends State<_CreateProductSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _active = true;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
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
      final api = ProductsApi(ApiClient());
      final created = await api.create(
        name: name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        active: _active,
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
            'Nový produkt',
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
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Popis (voliteľné)',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktívny'),
            value: _active,
            onChanged: _saving ? null : (v) => setState(() => _active = v),
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
                : const Text('Uložiť'),
          ),
        ],
      ),
    );
  }
}


