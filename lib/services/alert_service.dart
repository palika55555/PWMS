import '../services/material_service.dart';
import '../models/material.dart' as models;

class Alert {
  final String type; // 'low_stock', 'critical_stock'
  final String message;
  final models.Material material;

  Alert({
    required this.type,
    required this.message,
    required this.material,
  });
}

class AlertService {
  final MaterialService _materialService = MaterialService();

  // Kontrola nízkych zásob
  Future<List<Alert>> checkLowStock() async {
    final materials = await _materialService.getAllMaterials();
    final alerts = <Alert>[];

    for (var material in materials) {
      if (material.isLowStock) {
        final percentage = (material.quantity / material.minQuantity * 100).clamp(0, 100);
        final type = material.quantity == 0 ? 'critical_stock' : 'low_stock';
        final message = material.quantity == 0
            ? 'Kritický nedostatok!'
            : 'Nízke zásoby (${percentage.toStringAsFixed(0)}%)';

        alerts.add(Alert(
          type: type,
          message: message,
          material: material,
        ));
      }
    }

    return alerts;
  }

  // Počet varovaní
  Future<int> getAlertCount() async {
    final alerts = await checkLowStock();
    return alerts.length;
  }

  // Kritické varovania
  Future<List<Alert>> getCriticalAlerts() async {
    final alerts = await checkLowStock();
    return alerts.where((a) => a.type == 'critical_stock').toList();
  }
}

