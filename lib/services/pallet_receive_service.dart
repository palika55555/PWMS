// ====================================================================
// PALLET RECEIVE SERVICE - Flutter appka
// ====================================================================
// Služba pre príjem a naskladňovanie paliet po skenovaní QR kódu

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/pallet_service.dart';
import '../services/inventory_check_service.dart';
import '../models/pallet_label.dart';

class PalletReceiveService {
  /// Automaticky naskladní paletu po naskenovaní QR kódu
  /// 
  /// [context] - BuildContext pre zobrazenie správ
  /// [qrData] - surové dáta z QR kódu
  /// [quantity] - množstvo na naskladnenie (voliteľné, default 30 ks)
  /// 
  /// Vráti true ak naskladnenie prebehlo úspešne
  static Future<bool> receivePalletFromQR({
    required BuildContext context,
    required String qrData,
    int quantity = 30,
  }) async {
    try {
      final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
      final baseUrl = appSettingsProvider.apiBaseUrl;

      // 1. Extrahovanie dát z QR kódu
      final palletId = _extractPalletId(qrData);
      final productCode = _extractProductCode(qrData);
      
      if (palletId == null || productCode == null) {
        _showError(context, 'Neplatný QR kód palety');
        return false;
      }

      // 2. Kontrola, či je to PB-DT30
      if (productCode != 'PB-DT30') {
        _showError(context, 'Tento systém je určený len pre PB-DT30 tvarnice');
        return false;
      }

      // 3. Skontroluj, či produkt PB-DT30 existuje na sklade
      final productExists = await InventoryCheckService.checkProductExists('PB-DT30');
      
      if (!productExists) {
        // Vytvor produkt PB-DT30 ak neexistuje
        final created = await InventoryCheckService.ensurePbDt30Exists(
          context: context,
          quantity: 0, // Najprv vytvoríme bez množstva
        );
        
        if (!created) {
          _showError(context, 'Nepodarilo sa vytvoriť produkt PB-DT30');
          return false;
        }
      }

      // 4. Odošli paletu na backend (receive mode)
      await PalletService.scanPallet(
        baseUrl: baseUrl,
        mode: 'receive', // Príjem palety na sklad
        palletId: palletId,
        productCode: productCode,
        raw: qrData,
        quantity: quantity,
      );

      // 5. Aktualizuj množstvo v lokálnej databáze
      await InventoryCheckService.increaseProductQuantity('PB-DT30', quantity);

      // 6. Zobraz úspešnú správu
      _showSuccess(context, '✅ Paleta $palletId naskladnená ($quantity ks PB-DT30)');

      return true;
    } catch (e) {
      _showError(context, '❌ Chyba pri naskladňovaní: $e');
      return false;
    }
  }

  /// Hromadné naskladňovanie viacerých paliet
  /// 
  /// [context] - BuildContext pre zobrazenie správ
  /// [qrCodes] - zoznam QR kódov na naskladnenie
  /// [quantity] - množstvo na paletu (default 30 ks)
  /// 
  /// Vráti počet úspešne naskladnených paliet
  static Future<int> receiveMultiplePalletsFromQR({
    required BuildContext context,
    required List<String> qrCodes,
    int quantity = 30,
  }) async {
    int successCount = 0;
    
    for (int i = 0; i < qrCodes.length; i++) {
      final qrData = qrCodes[i];
      
      final success = await receivePalletFromQR(
        context: context,
        qrData: qrData,
        quantity: quantity,
      );
      
      if (success) {
        successCount++;
      }
      
      // Malá pauza medzi operáciami
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _showInfo(context, 'Hotovo! Naskladnených $successCount/${qrCodes.length} paliet');
    return successCount;
  }

  /// Vytvorí QR kód pre novú paletu a rovno ju naskladní
  /// 
  /// [context] - BuildContext
  /// [batchNumber] - číslo šarže
  /// [sequenceNumber] - postupné číslo palety
  /// [quantity] - množstvo na palete (default 30 ks)
  /// 
  /// Vráti vytvorený PalletLabel ak úspešné
  static Future<PalletLabel?> createAndReceivePallet({
    required BuildContext context,
    required String batchNumber,
    required int sequenceNumber,
    int quantity = 30,
  }) async {
    try {
      // 1. Vytvor štítok palety
      final label = PalletLabel.forPbDt30(
        batchNumber: batchNumber,
        sequenceNumber: sequenceNumber,
        productionDate: DateTime.now(),
      );

      // 2. Naskladni paletu pomocou QR kódu
      final success = await receivePalletFromQR(
        context: context,
        qrData: label.qrData,
        quantity: quantity,
      );

      if (success) {
        return label;
      } else {
        return null;
      }
    } catch (e) {
      _showError(context, '❌ Chyba pri vytváraní a naskladňovaní palety: $e');
      return null;
    }
  }

  /// Extrahuje ID palety z QR dát
  static String? _extractPalletId(String qrData) {
    try {
      // Skúsme parsovať JSON
      if (qrData.startsWith('{')) {
        final data = Map<String, dynamic>.from(
          Uri.splitQueryString(qrData.substring(1, qrData.length - 1))
        );
        return data['palletId'] as String?;
      }
      
      // Skúsime parsovať delimited formát
      final parts = qrData.split('|');
      if (parts.length >= 2) {
        return parts[0]; // Prvý prvok je ID palety
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extrahuje kód produktu z QR dát
  static String? _extractProductCode(String qrData) {
    try {
      // Skúsme parsovať JSON
      if (qrData.startsWith('{')) {
        final data = Map<String, dynamic>.from(
          Uri.splitQueryString(qrData.substring(1, qrData.length - 1))
        );
        return data['productCode'] as String?;
      }
      
      // Skúsime parsovať delimited formát
      final parts = qrData.split('|');
      if (parts.length >= 2) {
        return parts[1]; // Druhý prvok je kód produktu
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static void _showSuccess(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static void _showInfo(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
