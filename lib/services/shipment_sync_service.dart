import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class ShipmentSyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String API_BASE_URL = 'https://pwms.vercel.app/api/shipment';

  // Synchronizácia expedovania z API do lokálnej databázy
  Future<void> syncShipmentFromAPI(String batchNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL?batchNumber=$batchNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['shipment'] != null) {
          final shipment = data['shipment'];
          final shipped = shipment['shipped'] as bool? ?? false;
          final shippedDate = shipment['shippedDate'] as String?;
          final notes = shipment['notes'] as String?;

          if (shipped && shippedDate != null) {
            // Nájsť batch ID podľa batch number
            final db = await _db.database;
            final batches = await db.query(
              'production_batches',
              where: 'batch_number = ?',
              whereArgs: [batchNumber],
              limit: 1,
            );

            if (batches.isNotEmpty) {
              final batchId = batches.first['id'] as int;
              
              // Aktualizovať poznámky v production_batches
              final currentNotes = batches.first['notes'] as String? ?? '';
              final shipmentNote = notes != null 
                  ? '[Expedováno: $shippedDate] $notes'
                  : '[Expedováno: $shippedDate]';
              final updatedNotes = currentNotes.isEmpty 
                  ? shipmentNote 
                  : '$currentNotes\n$shipmentNote';
              
              await db.update(
                'production_batches',
                {
                  'notes': updatedNotes,
                },
                where: 'id = ?',
                whereArgs: [batchId],
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing shipment from API for $batchNumber: $e');
      rethrow;
    }
  }

  // Synchronizácia všetkých šarží z API
  Future<void> syncAllShipmentsFromAPI(List<String> batchNumbers) async {
    for (var batchNumber in batchNumbers) {
      try {
        await syncShipmentFromAPI(batchNumber);
      } catch (e) {
        print('Error syncing shipment for $batchNumber: $e');
        // Pokračovať s ďalšími šaržami aj keď jedna zlyhá
      }
    }
  }

  // Získanie aktuálneho stavu expedovania z API
  Future<Map<String, dynamic>?> getShipmentFromAPI(String batchNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL?batchNumber=$batchNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['shipment'] != null) {
          return data['shipment'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error getting shipment from API for $batchNumber: $e');
      return null;
    }
  }
}

