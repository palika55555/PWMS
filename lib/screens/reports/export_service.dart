import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';

class ExportService {
  Future<void> exportBatches(
    List<Batch> batches,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final filtered = batches.where((b) {
      final date = DateTime.parse(b.productionDate);
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    // Export to Excel
    final excel = Excel.createExcel();
    final sheet = excel['Šarže'];
    
    // Headers
    sheet.appendRow([
      TextCellValue('Číslo šarže'),
      TextCellValue('Dátum výroby'),
      TextCellValue('Množstvo'),
      TextCellValue('Status'),
      TextCellValue('Schválil'),
      TextCellValue('Poznámky'),
    ]);

    // Data
    for (final batch in filtered) {
      sheet.appendRow([
        TextCellValue(batch.batchNumber),
        TextCellValue(batch.productionDate),
        IntCellValue(batch.quantity),
        TextCellValue(_getStatusText(batch.qualityStatus)),
        TextCellValue(batch.qualityApprovedBy ?? ''),
        TextCellValue(batch.notes ?? ''),
      ]);
    }

    // Save and share
    final file = await _saveExcel(excel, 'sarze_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<String> exportMaterials(
    List<Material> materials, {
    List<String>? selectedColumns,
    String format = 'excel', // 'excel' or 'csv'
  }) async {
    // Default columns if not specified
    final columns = selectedColumns ?? [
      'name',
      'type',
      'category',
      'plu',
      'ean',
      'current_stock',
      'min_stock',
      'unit',
      'purchase_price',
      'sale_price',
      'vat_rate',
      'margin',
      'warehouse_number',
    ];
    
    if (format == 'csv') {
      return await _exportMaterialsToCsv(materials, columns);
    } else {
      return await _exportMaterialsToExcel(materials, columns);
    }
  }
  
  Future<String> _exportMaterialsToExcel(List<Material> materials, List<String> columns) async {
    final excel = Excel.createExcel();
    final sheet = excel['Materiály'];
    
    // Headers
    final headers = <TextCellValue>[];
    for (final col in columns) {
      headers.add(TextCellValue(_getColumnHeader(col)));
    }
    sheet.appendRow(headers);

    // Data rows
    for (final material in materials) {
      final row = <CellValue>[];
      for (final col in columns) {
        row.add(_getCellValueForColumn(material, col));
      }
      sheet.appendRow(row);
    }

    final file = await _saveExcel(excel, 'materialy_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    await Share.shareXFiles([XFile(file.path)]);
    return file.path;
  }
  
  Future<String> _exportMaterialsToCsv(List<Material> materials, List<String> columns) async {
    final buffer = StringBuffer();
    
    // Headers
    buffer.write(columns.map((col) => _getColumnHeader(col)).join(','));
    buffer.writeln();
    
    // Data rows
    for (final material in materials) {
      final values = <String>[];
      for (final col in columns) {
        final value = _getCellValueForColumn(material, col);
        String stringValue;
        if (value is TextCellValue) {
          final textValue = value.value;
          stringValue = textValue.toString();
        } else if (value is DoubleCellValue) {
          stringValue = value.value.toString();
        } else if (value is IntCellValue) {
          stringValue = value.value.toString();
        } else {
          stringValue = '';
        }
        // Escape commas and quotes
        if (stringValue.contains(',') || stringValue.contains('"')) {
          stringValue = '"${stringValue.replaceAll('"', '""')}"';
        }
        values.add(stringValue);
      }
      buffer.write(values.join(','));
      buffer.writeln();
    }
    
    final directory = await _getDownloadsDirectory();
    final file = File('${directory.path}/materialy_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)]);
    return file.path;
  }
  
  String _getColumnHeader(String column) {
    switch (column) {
      case 'name':
        return 'Názov';
      case 'type':
        return 'Typ';
      case 'category':
        return 'Kategória';
      case 'plu':
        return 'PLU';
      case 'ean':
        return 'EAN';
      case 'current_stock':
        return 'Aktuálny stav';
      case 'min_stock':
        return 'Minimálny stav';
      case 'unit':
        return 'Jednotka';
      case 'purchase_price':
        return 'Nákupná cena (s DPH)';
      case 'sale_price':
        return 'Predajná cena';
      case 'vat_rate':
        return 'DPH sadzba';
      case 'margin':
        return 'Marža';
      case 'warehouse_number':
        return 'Skladové číslo';
      case 'recycling_fee':
        return 'Recyklačný poplatok';
      default:
        return column;
    }
  }
  
  CellValue _getCellValueForColumn(Material material, String column) {
    switch (column) {
      case 'name':
        return TextCellValue(material.name);
      case 'type':
        return TextCellValue(material.type);
      case 'category':
        return TextCellValue(material.category);
      case 'plu':
        return TextCellValue(material.pluCode ?? '');
      case 'ean':
        return TextCellValue(material.eanCode ?? '');
      case 'current_stock':
        return DoubleCellValue(material.currentStock);
      case 'min_stock':
        return DoubleCellValue(material.minStock);
      case 'unit':
        return TextCellValue(material.unit);
      case 'purchase_price':
        return DoubleCellValue(material.averagePurchasePriceWithVat ?? 0.0);
      case 'sale_price':
        return DoubleCellValue(material.salePrice ?? 0.0);
      case 'vat_rate':
        return DoubleCellValue(material.vatRate ?? 0.0);
      case 'margin':
        final purchase = material.averagePurchasePriceWithVat ?? 0.0;
        final sale = material.salePrice ?? 0.0;
        return DoubleCellValue(sale > 0 && purchase > 0 ? sale - purchase : 0.0);
      case 'warehouse_number':
        return TextCellValue(material.warehouseNumber ?? '');
      case 'recycling_fee':
        return DoubleCellValue(material.recyclingFee ?? 0.0);
      default:
        return TextCellValue('');
    }
  }

  Future<void> exportStockMovements(List<StockMovement> movements) async {
    final excel = Excel.createExcel();
    final sheet = excel['Skladové pohyby'];
    
    sheet.appendRow([
      TextCellValue('Dátum'),
      TextCellValue('Typ'),
      TextCellValue('Množstvo'),
      TextCellValue('Jednotka'),
      TextCellValue('Dôvod'),
    ]);

    for (final movement in movements) {
      sheet.appendRow([
        TextCellValue(movement.movementDate),
        TextCellValue(_getMovementTypeText(movement.movementType)),
        DoubleCellValue(movement.quantity),
        TextCellValue(movement.unit),
        TextCellValue(movement.reason ?? ''),
      ]);
    }

    final file = await _saveExcel(excel, 'skladove_pohyby_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<File> _saveExcel(Excel excel, String filename) async {
    final directory = await _getDownloadsDirectory();
    final file = File('${directory.path}/$filename');
    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }
  
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isWindows) {
      // Windows: C:\Users\<username>\Downloads
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloadsPath = '$userProfile\\Downloads';
        final dir = Directory(downloadsPath);
        if (await dir.exists()) {
          return dir;
        }
      }
    } else if (Platform.isLinux) {
      // Linux: ~/Downloads
      final userHome = Platform.environment['HOME'];
      if (userHome != null) {
        final downloadsPath = '$userHome/Downloads';
        final dir = Directory(downloadsPath);
        if (await dir.exists()) {
          return dir;
        }
      }
    } else if (Platform.isMacOS) {
      // macOS: ~/Downloads
      final userHome = Platform.environment['HOME'];
      if (userHome != null) {
        final downloadsPath = '$userHome/Downloads';
        final dir = Directory(downloadsPath);
        if (await dir.exists()) {
          return dir;
        }
      }
    }
    
    // Fallback to application documents directory if Downloads doesn't exist
    return await getApplicationDocumentsDirectory();
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      case 'pending':
        return 'Čaká';
      default:
        return 'Neznámy';
    }
  }

  String _getMovementTypeText(String type) {
    switch (type) {
      case 'receipt':
        return 'Príjem';
      case 'issue':
        return 'Výdaj';
      case 'inventory_adjustment':
        return 'Inventúra';
      default:
        return type;
    }
  }
}

