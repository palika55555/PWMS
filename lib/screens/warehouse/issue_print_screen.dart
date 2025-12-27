import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/customer.dart';
import '../../models/material.dart' as material_model;
import '../../models/models.dart' hide Material;
import '../../models/warehouse.dart';

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
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
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
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
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
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: boldFont),
                        ),
                        pw.SizedBox(height: 6),
                        labelValue('Číslo výdajky', (issueNo != null && issueNo.isNotEmpty) ? issueNo : '—'),
                        labelValue('Dátum', dateFormat.format(DateTime.parse(_first.movementDate))),
                        if (warehouse != null) labelValue('Sklad', warehouse.name),
                        if (_first.reason != null && _first.reason!.trim().isNotEmpty) labelValue('Druh pohybu', _first.reason!.trim()),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
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
            pw.SizedBox(height: 18),

            // Items table
            pw.Text('Položky', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // name
                1: const pw.FlexColumnWidth(1), // qty
                2: const pw.FlexColumnWidth(1), // unit
                3: const pw.FlexColumnWidth(1.2), // sell unit no vat
                4: const pw.FlexColumnWidth(0.8), // vat
                5: const pw.FlexColumnWidth(1.2), // sell total with vat
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tovar', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Množ.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('MJ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cena bez', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('DPH', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Spolu s', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont))),
                  ],
                ),
                ...issues.map((i) {
                  final mat = i.materialId != null ? materialsMap[i.materialId] : null;
                  final name = mat?.name ?? 'Neznámy tovar';
                  final sellU = i.purchasePriceWithoutVat ?? 0;
                  final vat = i.vatRate ?? (mat?.vatRate ?? 20);
                  final sellUw = i.purchasePriceWithVat ?? (sellU * (1 + vat / 100));
                  final totalWith = sellUw * i.quantity;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.unit, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(sellU), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${vat.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fMoney.format(totalWith), style: const pw.TextStyle(fontSize: 9))),
                    ],
                  );
                }),
              ],
            ),

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
}


