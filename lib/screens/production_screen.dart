import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/production.dart';
import '../models/production_type.dart';
import '../services/api_service.dart';
import 'production_form_screen.dart';
import 'recipes_screen.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Production> _productions = [];
  List<ProductionType> _productionTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final productions = await apiService.getProductions();
      final types = await apiService.getProductionTypes();
      setState(() {
        _productions = productions;
        _productionTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní dát: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduction(Production production) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdiť vymazanie'),
        content: Text('Naozaj chcete vymazať výrobu "${production.productionTypeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.deleteProduction(production.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Výroba bola vymazaná')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba pri vymazávaní: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výroba'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Späť',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Typy výroby: ${_productionTypes.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecipesScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('Recepty'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductionFormScreen(),
                            ),
                          );
                          _loadData();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nová výroba'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _productions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Žiadna výroba',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pridajte novú výrobu pomocou tlačidla vyššie',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _productions.length,
                          itemBuilder: (context, index) {
                            final production = _productions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    production.quantity.toStringAsFixed(0),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(production.productionTypeName ?? 'Neznámy typ'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dátum: ${production.productionDate != null ? DateFormat('dd.MM.yyyy HH:mm').format(production.productionDate!) : 'N/A'}',
                                    ),
                                    if (production.notes != null)
                                      Text('Poznámka: ${production.notes}'),
                                    Text(
                                      'Materiály: ${production.materials.length}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteProduction(production),
                                  color: Colors.red,
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  // TODO: Show production details
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductionFormScreen(),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
