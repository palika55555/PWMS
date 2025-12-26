import 'package:flutter/material.dart' hide Material;
import 'package:fl_chart/fl_chart.dart';
import '../../../models/models.dart' show Material;

class StockChart extends StatelessWidget {
  final List<Material> materials;

  const StockChart({super.key, required this.materials});

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return Center(
        child: Text(
          'Žiadne dáta',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: materials.map((material) {
          return PieChartSectionData(
            value: material.currentStock,
            title: '${material.currentStock.toStringAsFixed(0)}',
            color: _getMaterialColor(material.type),
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getMaterialColor(String type) {
    switch (type) {
      case 'cement':
        return Colors.grey;
      case 'aggregate':
        return Colors.brown;
      case 'water':
        return Colors.blue;
      case 'plasticizer':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }
}

