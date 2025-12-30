import 'dart:async';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/material.dart' as material_model;
import '../../models/models.dart' hide Material;

class IssuePrintScreen extends StatelessWidget {
  final List<StockMovement> issues; // all lines for one issue doc
  final Map<int, material_model.Material> materialsMap;
  final Map<int, Warehouse>? warehousesMap;
  final Map<int, Customer>? customersMap;

  const IssuePrintScreen({
    super.key,
    required this.issues,
    required this.materialsMap,
    this.warehousesMap,
    this.customersMap,
  });

  StockMovement get _first => issues.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tlač výdajky'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _print(context),
            tooltip: 'Tlačiť',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
            tooltip: 'Zdieľať PDF',
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => _generatePdf(context),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    final pdf = await _generatePdf(context);
    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  Future<void> _share(BuildContext context) async {
    final pdf = await _generatePdf(context);
    final name = _first.receiptNumber?.trim().isNotEmpty == true ? _first.receiptNumber!.trim() : 'vydajka-${_first.id}';
    await Printing.sharePdf(bytes: pdf, filename: '$name.pdf');
  }

  Future<Uint8List> _generatePdf(BuildContext context) async {
    // Unicode fonts (Slovak)
    pw.Font? ttf;
    pw.Font? ttfBold;

    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      final response = await http
          .get(Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Regular.ttf'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
        ttf = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
      }
    }

    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      ttfBold = pw.Font.ttf(fontData);
    } catch (_) {
      // optional
      if (ttf != null) {
        try {
          final response = await http
              .get(Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Bold.ttf'))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
            ttfBold = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
          }
        } catch (_) {}
      }
    }

    if (ttf == null) {
      throw Exception('Nepodarilo sa načítať Unicode font pre PDF.');
    }

    final regularFont = ttf;
    final boldFont = ttfBold ?? ttf;

    final dateFormat = DateFormat('dd.MM.yyyy');
    final dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

    final issueNo = _first.receiptNumber?.trim();
    final docNo = _first.documentNumber?.trim();
    final warehouse = (_first.warehouseId != null && warehousesMap != null) ? warehousesMap![_first.warehouseId] : null;
    final customer = (_first.customerId != null && customersMap != null) ? customersMap![_first.customerId] : null;

    // Totals (predaj = sale unit stored in purchasePrice* fields on movement)
    pw.Widget labelValue(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 100,
              child: pw.Text('$label:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700,)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      );
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (ctx) {
          final fMoney = NumberFormat.currency(symbol: '€', decimalDigits: 2);
          
          // Determine pricing mode from the data
          final pricingModes = issues.map((i) => i.pricingMode ?? 'sale').toSet();
          final isVatExempt = pricingModes.contains('vat_exempt');
          final usesPurchasePrice = pricingModes.contains('purchase');
          
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VÝDAJKA',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont),
                        ),
                        pw.SizedBox(height: 4),
                        labelValue('Číslo výdajky', (issueNo != null && issueNo.isNotEmpty) ? issueNo : '—'),
                        labelValue('Dátum', dateFormat.format(DateTime.parse(_first.movementDate))),
                        if (warehouse != null) labelValue('Sklad', warehouse.name),
                        if (_first.reason != null && _first.reason!.trim().isNotEmpty) labelValue('Druh pohybu', _first.reason!.trim()),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        labelValue('Číslo dokladu', (docNo != null && docNo.isNotEmpty) ? docNo : '—'),
                        labelValue('Zákazník', customer?.name ?? (_first.recipientName?.trim().isNotEmpty == true ? _first.recipientName!.trim() : '—')),
                        if (_first.location != null && _first.location!.trim().isNotEmpty) labelValue('Miesto', _first.location!.trim()),
                        labelValue('Vytvorené', dateTimeFormat.format(DateTime.parse(_first.createdAt))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Items table
            pw.Text('Položky', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.SizedBox(height: 8),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: _getTableColumnWidths(isVatExempt, usesPurchasePrice),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: _getTableHeaders(isVatExempt, usesPurchasePrice, boldFont),
                ),
                ...issues.map((i) => _buildItemRow(i, materialsMap, fMoney, isVatExempt, usesPurchasePrice)),
              ],
            ),

            pw.SizedBox(height: 18),

            // Summary section
            _buildSummarySection(issues, fMoney, isVatExempt, boldFont),

            pw.SizedBox(height: 18),
          

            if (_first.notes != null && _first.notes!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text('Poznámka', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: boldFont)),
              pw.SizedBox(height: 4),
              pw.Text(_first.notes!.trim(), style: const pw.TextStyle(fontSize: 10)),
            ],

            // Signature and stamp section (like receipt PDF)
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        '................................................................................',
                        style: pw.TextStyle(fontSize: 8, font: regularFont, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Vydal${_first.createdBy.trim().isNotEmpty ? ': ${_first.createdBy}' : ''}',
                        style: pw.TextStyle(fontSize: 9, font: regularFont, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        '................................................................................',
                        style: pw.TextStyle(fontSize: 8, font: regularFont, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Pečiatka a Podpis',
                        style: pw.TextStyle(fontSize: 9, font: regularFont, color: PdfColors.black),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Vytvoril: ${_first.createdBy}',
                  style: pw.TextStyle(fontSize: 6, font: regularFont),
                ),
                pw.Text(
                  'Vytlačené: ${dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 6, font: regularFont),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Map<int, pw.FlexColumnWidth> _getTableColumnWidths(bool isVatExempt, bool usesPurchasePrice) {
    if (isVatExempt) {
      // VAT exempt: name, qty, unit, unit price, total
      return {
        
        0: const pw.FlexColumnWidth(0.5), // code
        1: const pw.FlexColumnWidth(3.5), // name
        2: const pw.FlexColumnWidth(1), // qty
        3: const pw.FlexColumnWidth(0.8), // unit
        4: const pw.FlexColumnWidth(1.2), // unit price
        5: const pw.FlexColumnWidth(1.2), // total
      };
    } else {
      // Normal VAT: name, qty, unit, unit price, vat, total
      return {
        0: const pw.FlexColumnWidth(0.5), // code
        1: const pw.FlexColumnWidth(3), // name
        2: const pw.FlexColumnWidth(1), // qty
        3: const pw.FlexColumnWidth(0.8), // unit
        4: const pw.FlexColumnWidth(1), // unit price
        5: const pw.FlexColumnWidth(0.8), // vat
        6: const pw.FlexColumnWidth(1.2), // total
      };
    }
  }

  List<pw.Widget> _getTableHeaders(bool isVatExempt, bool usesPurchasePrice, pw.Font boldFont) {
    if (isVatExempt) {
      return [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Kód', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Tovar', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Množ.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MJ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cena', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cena s DPH', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
      ];
    } else {
      return [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Kód', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Tovar', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Množ.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MJ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cena bez', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('DPH', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Cena s DPH', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont))),
      ];
    }
  }

  pw.TableRow _buildItemRow(StockMovement i, Map<int, material_model.Material> materialsMap, NumberFormat fMoney, bool isVatExempt, bool usesPurchasePrice) {
    final mat = i.materialId != null ? materialsMap[i.materialId] : null;
    final name = mat?.name ?? 'Neznámy tovar';
    final code = mat?.id?.toString() ?? '';
    final pricingMode = i.pricingMode ?? 'sale';
    
    // Determine pricing based on pricing mode
    double unitPrice;
    double total;
    
    if (pricingMode == 'purchase') {
      // Use actual purchase price from material
      unitPrice = mat?.averagePurchasePriceWithoutVat ?? i.purchasePriceWithoutVat ?? 0;
      total = unitPrice * i.quantity;
    } else if (pricingMode == 'vat_exempt') {
      // For VAT exempt, use sale price without VAT
      unitPrice = mat?.salePrice ?? i.purchasePriceWithoutVat ?? 0;
      total = unitPrice * i.quantity;
    } else {
      // Normal sale pricing
      unitPrice = mat?.salePrice ?? mat?.averagePurchasePriceWithoutVat ?? i.purchasePriceWithoutVat ?? 0;
      final vatRate = i.vatRate ?? (mat?.vatRate ?? 20);
      final unitPriceWithVat = unitPrice * (1 + vatRate / 100);
      total = unitPriceWithVat * i.quantity;
    }

    if (isVatExempt || pricingMode == 'vat_exempt') {
      return pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(code, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2), style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.unit, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(unitPrice), style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(total), style: const pw.TextStyle(fontSize: 7))),
        ],
      );
    } else {
      final vatRate = i.vatRate ?? (mat?.vatRate ?? 20);
      return pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(code, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2), style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.unit, style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(unitPrice), style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${vatRate.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(total), style: const pw.TextStyle(fontSize: 7))),
        ],
      );
    }
  }

  pw.Widget _buildSummarySection(List<StockMovement> issues, NumberFormat fMoney, bool isVatExempt, pw.Font boldFont) {
    double totalWithoutVat = 0;
    double totalVat = 0;
    double totalWithVat = 0;

    for (final issue in issues) {
      final mat = issue.materialId != null ? materialsMap[issue.materialId] : null;
      final pricingMode = issue.pricingMode ?? 'sale';
      final vatRate = issue.vatRate ?? 0;
      
      double unitPrice;
      
      if (pricingMode == 'purchase') {
        // Use actual purchase price from material
        unitPrice = mat?.averagePurchasePriceWithoutVat ?? issue.purchasePriceWithoutVat ?? 0;
      } else if (pricingMode == 'vat_exempt') {
        // For VAT exempt, use sale price without VAT
        unitPrice = mat?.salePrice ?? issue.purchasePriceWithoutVat ?? 0;
      } else {
        // Normal sale pricing
        unitPrice = mat?.salePrice ?? mat?.averagePurchasePriceWithoutVat ?? issue.purchasePriceWithoutVat ?? 0;
      }
      
      totalWithoutVat += unitPrice * issue.quantity;
      
      if (pricingMode == 'vat_exempt' || isVatExempt) {
        // No VAT for exempt items
        totalWithVat = totalWithVat + unitPrice * issue.quantity;
      } else {
        // Normal VAT calculation
        final unitPriceWithVat = unitPrice * (1 + vatRate / 100);
        totalVat = totalVat + (unitPriceWithVat - unitPrice) * issue.quantity;
        totalWithVat = totalWithVat + unitPriceWithVat * issue.quantity;
      }
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 150,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.2),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: _buildSummaryRows(totalWithoutVat, totalVat, totalWithVat, isVatExempt, fMoney, boldFont),
        ),
      ),
    );
  }

  List<pw.Widget> _buildSummaryRows(double totalWithoutVat, double totalVat, double totalWithVat, bool isVatExempt, NumberFormat fMoney, pw.Font boldFont) {
    final rows = <pw.Widget>[];
    
    if (!isVatExempt) {
      rows.addAll([
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Medzisúčet:', style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(width: 6),
            pw.Text(
              fMoney.format(totalWithoutVat),
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('DPH:', style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(width: 3),
            pw.Text(
              fMoney.format(totalVat),
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              isVatExempt ? 'Spolu (bez DPH):' : 'Spolu s DPH:',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              fMoney.format(totalWithVat),
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: boldFont),
            ),
          ],
        ),
      ]);
    }
    
    
    return rows;
  }
}


