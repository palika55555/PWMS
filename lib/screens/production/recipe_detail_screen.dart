import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/database_provider.dart';
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;

class RecipeDetailScreen extends StatelessWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Recipe?>(
      future: Provider.of<DatabaseProvider>(context, listen: false)
          .getRecipe(recipeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Receptúra')),
            body: const Center(child: Text('Receptúra nebola nájdená')),
          );
        }

        final recipe = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.name),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Základné informácie',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildInfoRow(context, 'Názov', recipe.name),
                      _buildInfoRow(context, 'Typ produktu', recipe.productType),
                      if (recipe.description != null)
                        _buildInfoRow(context, 'Popis', recipe.description!),
                      if (recipe.wcRatio != null)
                        _buildInfoRow(context, 'Pomer V/C', recipe.wcRatio!.toStringAsFixed(2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zloženie receptúry',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildInfoRow(context, 'Cement', '${recipe.cementAmount} kg'),
                      _buildInfoRow(context, 'Voda', '${recipe.waterAmount} l'),
                      if (recipe.plasticizerAmount != null)
                        _buildInfoRow(context, 'Plastifikátor', '${recipe.plasticizerAmount} l'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Provider.of<DatabaseProvider>(context, listen: false)
                    .getRecipeAggregates(recipeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agregáty',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            Text(
                              'Žiadne agregáty',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final aggregates = snapshot.data!;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agregáty',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          ...aggregates.map((agg) {
                            final material = agg['material'] as material_model.Material?;
                            final fraction = agg['fraction'] as Map<String, dynamic>?;
                            final amount = (agg['amount'] as num).toDouble();
                            
                            if (material == null) return const SizedBox.shrink();
                            
                            final name = fraction != null
                                ? '${material.name} - ${fraction['fraction_name']}'
                                : material.name;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (fraction != null)
                                          Text(
                                            '${fraction['size_min']} - ${fraction['size_max']} mm',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${amount.toStringAsFixed(2)} ${material.unit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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
}

