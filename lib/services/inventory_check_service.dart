// ====================================================================
// INVENTORY CHECK SERVICE - Flutter appka
// ====================================================================
// Služba pre kontrolu existencie produktov na sklade

import 'package:flutter/material.dart';
import '../providers/database_provider.dart';
import '../models/material.dart' as material_model;

class InventoryCheckService {
  /// Skontroluje, či produkt s daným názvom existuje na sklade
  /// 
  /// [productName] - názov produktu (napr. "PB-DT30")
  /// Vráti true ak produkt existuje, false inak
  static Future<bool> checkProductExists(String productName) async {
    try {
      print('🔍 DEBUG: Spúšťam checkProductExists pre: $productName');
      final dbProvider = DatabaseProvider();
      final db = await dbProvider.getDatabase();
      print('🔍 DEBUG: Databáza pripojená');
      
      final result = await db.query(
        'materials',
        where: 'name = ?',
        whereArgs: [productName],
      );
      print('🔍 DEBUG: Query výsledok: nájdených ${result.length} záznamov');
      
      if (result.isNotEmpty) {
        print('🔍 DEBUG: Nájdený produkt: ${result.first}');
      }
      
      return result.isNotEmpty;
    } catch (e) {
      print('🔍 DEBUG: CHYBA v checkProductExists: $e');
      throw Exception('Chyba pri kontrole produktu: $e');
    }
  }

  /// Získa informácie o produkte z databázy
  /// 
  /// [productName] - názov produktu
  /// Vráti Material objekt alebo null ak neexistuje
  static Future<material_model.Material?> getProductInfo(String productName) async {
    try {
      final dbProvider = DatabaseProvider();
      final db = await dbProvider.getDatabase();
      
      final result = await db.query(
        'materials',
        where: 'name = ?',
        whereArgs: [productName],
      );
      
      if (result.isEmpty) return null;
      
      return material_model.Material.fromMap(result.first);
    } catch (e) {
      throw Exception('Chyba pri získavaní informácií o produkte: $e');
    }
  }

  /// Vytvorí nový produkt na sklade s preddefinovanými hodnotami pre PB-DT30
  /// 
  /// Vráti vytvorený Material objekt
  static Future<material_model.Material> createPbDt30Product() async {
    try {
      final dbProvider = DatabaseProvider();
      final db = await dbProvider.getDatabase();
      
      final now = DateTime.now().toIso8601String();
      
      final product = material_model.Material(
        name: 'PB-DT30',
        type: 'production', // Typ pre výrobok
        category: 'production', // Kategória pre výrobu
        unit: 'ks',
        currentStock: 0, // Začiatok s nulovým stavom
        minStock: 30, // Minimálny stav pre jednu paletu
        averagePurchasePriceWithoutVat: 0.0, // Cena sa nastaví neskôr
        salePrice: 0.0,
        vatRate: 20.0,
        hasRecyclingFee: false,
        synced: 0,
        createdAt: now,
        updatedAt: now,
      );

      final id = await db.insert('materials', product.toMap());
      
      return material_model.Material(
        id: id,
        name: product.name,
        type: product.type,
        category: product.category,
        unit: product.unit,
        currentStock: product.currentStock,
        minStock: product.minStock,
        averagePurchasePriceWithoutVat: product.averagePurchasePriceWithoutVat,
        salePrice: product.salePrice,
        vatRate: product.vatRate,
        hasRecyclingFee: product.hasRecyclingFee,
        synced: product.synced,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );
    } catch (e) {
      throw Exception('Chyba pri vytváraní produktu PB-DT30: $e');
    }
  }

  /// Zvýši množstvo produktu na sklade
  /// 
  /// [productName] - názov produktu
  /// [quantity] - množstvo na pridanie
  static Future<void> increaseProductQuantity(String productName, int quantity) async {
    try {
      print('🔍 DEBUG: Aktualizujem množstvo pre $productName o $quantity ks');
      final dbProvider = DatabaseProvider();
      final db = await dbProvider.getDatabase();
      
      await db.rawUpdate(
        'UPDATE materials SET current_stock = current_stock + ?, updated_at = ? WHERE name = ?',
        [quantity.toDouble(), DateTime.now().toIso8601String(), productName],
      );
      print('🔍 DEBUG: Množstvo úspešne aktualizované');
    } catch (e) {
      print('🔍 DEBUG: CHYBA v increaseProductQuantity: $e');
      throw Exception('Chyba pri aktualizácii množstva: $e');
    }
  }

  /// Kompletná kontrola a prípadné vytvorenie produktu PB-DT30
  /// 
  /// [context] - BuildContext pre zobrazenie dialógov
  /// [quantity] - množstvo na pridať (voliteľné)
  /// Vráti true ak produkt existoval alebo bol úspešne vytvorený
  static Future<bool> ensurePbDt30Exists({
    required BuildContext context,
    int quantity = 0,
  }) async {
    try {
      print('🔍 DEBUG: Hľadám produkt PB-DT30...');
      final exists = await checkProductExists('PB-DT30');
      print('🔍 DEBUG: Produkt PB-DT30 existuje: $exists');
      
      if (exists) {
        // Produkt existuje, pridáme množstvo ak je zadané
        if (quantity > 0) {
          print('🔍 DEBUG: Pridávam množstvo $quantity ks k PB-DT30...');
          await increaseProductQuantity('PB-DT30', quantity);
          print('🔍 DEBUG: Množstvo pridané');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Produkt PB-DT30 existuje, množstvo zvýšené o $quantity ks'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        return true;
      } else {
        // Produkt neexistuje, ponúkneme vytvorenie
        print('🔍 DEBUG: Produkt PB-DT30 neexistuje, zobrazujem dialóg...');
        return await _showCreateProductDialog(context, quantity);
      }
    } catch (e) {
      print('🔍 DEBUG: CHYBA v ensurePbDt30Exists: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba pri kontrole produktu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Zobrazí dialóg pre vytvorenie produktu PB-DT30
  static Future<bool> _showCreateProductDialog(BuildContext context, int quantity) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Produkt PB-DT30 neexistuje'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produkt "PB-DT30" nebol nájdený v skladovej evidencii.\n'
              'Chcete ho automaticky vytvoriť s nasledujúcimi parametrami?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Názov:', 'PB-DT30'),
                  _buildDetailRow('Typ:', 'Výrobný materiál'),
                  _buildDetailRow('Kategória:', 'Výroba'),
                  _buildDetailRow('Jednotka:', 'ks'),
                  _buildDetailRow('Množstvo:', quantity > 0 ? '$quantity ks' : '0 ks'),
                  _buildDetailRow('Min. stav:', '30 ks (1 paleta)'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vytvoriť produkt'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await createPbDt30Product();
        if (quantity > 0) {
          await increaseProductQuantity('PB-DT30', quantity);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Produkt PB-DT30 vytvorený${quantity > 0 ? ' a množstvo $quantity ks pridané' : ''}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Chyba pri vytváraní produktu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    
    return false;
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
