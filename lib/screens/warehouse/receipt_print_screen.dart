import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../../models/models.dart' hide Material;
import '../../models/material.dart' as material_model;
import '../../models/supplier.dart';

class ReceiptPrintScreen extends StatelessWidget {
  final StockMovement receipt;
  final material_model.Material? material;
  final Supplier? supplier;
  final List<StockMovement>? allReceipts; // All receipts with same receiptNumber
  final Map<int, material_model.Material>? materialsMap; // Map of materials for all receipts

  const ReceiptPrintScreen({
    super.key,
    required this.receipt,
    this.material,
    this.supplier,
    this.allReceipts,
    this.materialsMap,
  });

  // Format purchase price with 4 decimal places for small values
  static String formatPurchasePrice(double? price) {
    if (price == null) return '';
    if (price == 0) return '0.0000';
    
    // For very small prices (less than 0.01), show up to 4 decimal places
    if (price < 0.01) {
      return price.toStringAsFixed(4);
    }
    // For normal prices, show 2 decimal places
    return price.toStringAsFixed(2);
  }

  // Format sale price with 2 decimal places
  static String formatSalePrice(double? price) {
    if (price == null) return '';
    if (price == 0) return '0.00';
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tlač príjemky'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReceipt(context),
            tooltip: 'Tlačiť',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReceipt(context),
            tooltip: 'Zdieľať PDF',
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(context),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    final pdf = await _generatePdf(context);
    await Printing.layoutPdf(
      onLayout: (format) async => pdf,
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final pdf = await _generatePdf(context);
    final prefix = receipt.notes == 'Rýchly príjem' ? 'rychly-prijem' : 'prijemka';
    await Printing.sharePdf(
      bytes: pdf,
      filename: '$prefix-${receipt.receiptNumber ?? receipt.id}.pdf',
    );
  }

  Future<Uint8List> _generatePdf(BuildContext context) async {
    // Load Unicode fonts for Slovak characters from assets
    // OpenSans fonts have full Unicode support including all Slovak characters (Č, Ľ, Ž, Ď, Š, Č, etc.)
    pw.Font? ttf;
    pw.Font? ttfBold;
    
    // Load regular font from assets (primary source)
    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      ttf = pw.Font.ttf(fontData);
      print('✓ Regular font loaded from assets (Unicode support enabled)');
    } catch (e) {
      print('⚠ Failed to load Regular font from assets: $e');
      // Fallback: try to download from CDN if assets are missing
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Regular.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          ttf = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
          print('✓ Regular font loaded from CDN fallback');
        }
      } catch (e2) {
        print('⚠ Failed to load Regular font from CDN: $e2');
      }
    }
    
    // Load bold font from assets (primary source)
    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      ttfBold = pw.Font.ttf(fontData);
      print('✓ Bold font loaded from assets (Unicode support enabled)');
    } catch (e) {
      print('⚠ Failed to load Bold font from assets: $e');
      // Fallback: try to download from CDN if assets are missing
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Bold.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          ttfBold = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
          print('✓ Bold font loaded from CDN fallback');
        }
      } catch (e2) {
        print('⚠ Failed to load Bold font from CDN: $e2');
      }
    }
    
    // If no fonts loaded, throw error
    if (ttf == null) {
      throw Exception(
        'Nepodarilo sa načítať Unicode fonty. Prosím skontrolujte:\n'
        '1. Či sú súbory OpenSans-Regular.ttf a OpenSans-Bold.ttf v priečinku assets/fonts/\n'
        '2. Či je správne nakonfigurovaný pubspec.yaml s assets/fonts/\n'
        '3. Spustite "flutter pub get" a reštartujte aplikáciu\n\n'
        'Bez Unicode fontov sa slovenské znaky (Č, Ľ, Ž, Ď, Š, Č, ž, š, č) nemusia zobraziť správne.'
      );
    }
    
    // Use regular font as fallback for bold if bold is not available
    final regularFont = ttf;
    final boldFont = ttfBold ?? ttf;
    
    print('📄 PDF fonts ready - Regular: ✓, Bold: ${ttfBold != null ? "✓" : "using regular"}');
    
    final pdf = pw.Document();
    // Set UTF-8 encoding for the document
    final dateFormat = DateFormat('dd.MM.yyyy');
    final dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          // Calculate totals for all receipts
          double totalWithoutVat = 0;
          double totalWithVat = 0;
          double? commonVatRate;
          
          for (final r in (allReceipts ?? [receipt])) {
            if (r.purchasePriceWithoutVat != null && r.quantity > 0) {
              totalWithoutVat += r.purchasePriceWithoutVat! * r.quantity;
            }
            if (r.purchasePriceWithVat != null && r.quantity > 0) {
              totalWithVat += r.purchasePriceWithVat! * r.quantity;
            }
            if (r.vatRate != null) {
              commonVatRate ??= r.vatRate;
            }
          }
          
          // Ensure UTF-8 encoding for all text
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with thin border
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
                            receipt.notes == 'Rýchly príjem' ? 'RÝCHLY PRÍJEM' : 'PRÍJEMKA',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          if (receipt.receiptNumber != null)
                            pw.Text(
                              'Číslo: ${receipt.receiptNumber}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                          if (receipt.documentNumber != null) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Číslo dodacieho listu: ${receipt.documentNumber}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Počet položiek: ${(allReceipts?.length ?? 1)}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Dátum príjmu:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                        pw.Text(
                          dateFormat.format(DateTime.parse(receipt.movementDate)),
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: regularFont,
                          ),
                        ),
                        if (receipt.deliveryDate != null) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Dátum dodania:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            dateFormat.format(DateTime.parse(receipt.deliveryDate!)),
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                        if (receipt.createdAt.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Vytvorené:',
                            style: pw.TextStyle(
                              fontSize: 6,
                              font: regularFont,
                            ),
                          ),
                          pw.Text(
                            dateTimeFormat.format(DateTime.parse(receipt.createdAt)),
                            style: pw.TextStyle(
                              fontSize: 6,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Supplier info
              if (supplier != null || receipt.supplierName != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Dodávateľ:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        supplier?.name ?? receipt.supplierName ?? '',
                        style: pw.TextStyle(
                          fontSize: 9,
                          font: regularFont,
                        ),
                      ),
                      if (supplier != null && ((supplier!.address?.isNotEmpty ?? false) || (supplier!.city?.isNotEmpty ?? false))) ...[
                        pw.SizedBox(height: 2),
                        if (supplier!.address != null && supplier!.address!.isNotEmpty)
                          pw.Text(
                            supplier!.address!,
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        if (supplier!.city != null && supplier!.city!.isNotEmpty)
                          pw.Text(
                            '${supplier!.city}${(supplier!.zipCode?.isNotEmpty ?? false) ? ', ${supplier!.zipCode}' : ''}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                      ],
                      if (supplier != null && supplier!.companyId != null && supplier!.companyId!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'IČO: ${supplier!.companyId}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: regularFont,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
              ],

              // Prices table
              if (receipt.purchasePriceWithVat != null || receipt.purchasePriceWithoutVat != null) ...[
                pw.Text(
                  'Prijatý tovar:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder(
                    left: const pw.BorderSide(color: PdfColors.grey400, width: 1),
                    top: const pw.BorderSide(color: PdfColors.grey400, width: 1),
                    right: const pw.BorderSide(color: PdfColors.grey400, width: 1),
                    bottom: const pw.BorderSide(color: PdfColors.grey400, width: 1),
                    horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    verticalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Tovar',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Kategória',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'PLU',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Množstvo',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Nákup bez DPH',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Nákup s DPH',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'DPH',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            'Celkom',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              font: boldFont,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Add rows for all receipts
                    ...((allReceipts ?? [receipt]).map((r) {
                      final mat = r.materialId != null && materialsMap != null 
                          ? materialsMap![r.materialId] 
                          : (r == receipt ? material : null);
                      return pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              mat?.name ?? 'Materiál',
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              _getCategoryLabel(mat?.category),
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              mat?.pluCode ?? '-',
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              '${r.quantity.toStringAsFixed(2)} ${r.unit}',
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              r.purchasePriceWithoutVat != null
                                  ? '${formatPurchasePrice(r.purchasePriceWithoutVat)} €'
                                  : '-',
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              r.purchasePriceWithVat != null
                                  ? '${formatPurchasePrice(r.purchasePriceWithVat)} €'
                                  : '-',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                font: boldFont,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Text(
                              r.vatRate != null
                                  ? '${r.vatRate!.toStringAsFixed(0)}%'
                                  : '-',
                              style: pw.TextStyle(
                                fontSize: 7,
                                font: regularFont,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                if (r.purchasePriceWithoutVat != null && r.quantity > 0)
                                  pw.Text(
                                    '${formatPurchasePrice(r.purchasePriceWithoutVat! * r.quantity)} €',
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      font: regularFont,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                if (r.purchasePriceWithVat != null && r.quantity > 0)
                                  pw.Text(
                                    '${formatPurchasePrice(r.purchasePriceWithVat! * r.quantity)} €',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      font: boldFont,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                if (r.purchasePriceWithVat == null && r.purchasePriceWithoutVat == null)
                                  pw.Text(
                                    '-',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      font: boldFont,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    })),
                  ],
                ),
                pw.SizedBox(height: 15),
              ],

              // Product specific info
              if (receipt.productNote != null || receipt.expirationDate != null) ...[
                pw.Text(
                  'Informácie o produkte:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (receipt.productNote != null)
                  pw.Text(
                    'Poznámka k produktu: ${receipt.productNote}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      font: regularFont,
                    ),
                  ),
                if (receipt.expirationDate != null) ...[
                  if (receipt.productNote != null) pw.SizedBox(height: 3),
                  pw.Text(
                    'Dátum expirácie: ${dateFormat.format(DateTime.parse(receipt.expirationDate!))}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      font: regularFont,
                    ),
                  ),
                ],
                pw.SizedBox(height: 12),
              ],

              // Additional info
              if (receipt.location != null || receipt.notes != null) ...[
                pw.Text(
                  'Ďalšie informácie:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    font: boldFont,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (receipt.location != null)
                  pw.Text(
                    'Miesto skladu: ${receipt.location}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      font: regularFont,
                    ),
                  ),
                if (receipt.notes != null)
                  pw.Text(
                    'Poznámky: ${receipt.notes}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      font: regularFont,
                    ),
                  ),
                pw.SizedBox(height: 15),
              ],

              pw.Spacer(),

              // Summary section - Súhrn (totals calculated at top of build method)
              if (totalWithVat > 0 || totalWithoutVat > 0 || receipt.purchasePriceWithVat != null || receipt.purchasePriceWithoutVat != null) ...[
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (totalWithoutVat > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Celkom bez DPH:',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                            pw.Text(
                              '${formatPurchasePrice(totalWithoutVat)} €',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      if (commonVatRate != null && totalWithoutVat > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'DPH (${commonVatRate.toStringAsFixed(0)}%):',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                            pw.Text(
                              '${formatPurchasePrice(totalWithVat - totalWithoutVat)} €',
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      pw.Divider(),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Suma spolu:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            totalWithVat > 0
                                ? '${formatPurchasePrice(totalWithVat)} €'
                                : '-',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                        ],
                      ),
                      if (commonVatRate != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Tovary boli prijaté za DPH ${commonVatRate.toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontStyle: pw.FontStyle.italic,
                            font: regularFont,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Status
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Stav: ',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        font: boldFont,
                      ),
                    ),
                    pw.Text(
                      _getStatusText(receipt.status),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _getStatusColor(receipt.status),
                        font: regularFont,
                      ),
                    ),
                    if (receipt.approvedBy != null) ...[
                      pw.Spacer(),
                      pw.Text(
                        'Schválil: ${receipt.approvedBy}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          font: regularFont,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Signature and stamp section
              pw.SizedBox(height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Dots line
                  pw.Text(
                    '................................................................................',
                    style: pw.TextStyle(
                      fontSize: 8,
                      font: regularFont,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  // Text centered below the dots
                  pw.Text(
                    'Pečiatka a Podpis',
                    style: pw.TextStyle(
                      fontSize: 9,
                      font: regularFont,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
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
                    'Vytvoril: ${receipt.createdBy}',
                            style: pw.TextStyle(
                              fontSize: 6,
                              font: regularFont,
                            ),
                  ),
                  pw.Text(
                    'Vytlačené: ${dateTimeFormat.format(DateTime.now())}',
                            style: pw.TextStyle(
                              fontSize: 6,
                              font: regularFont,
                            ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _getCategoryLabel(String? category) {
    if (category == null) return '-';
    switch (category) {
      case 'warehouse':
        return 'Sklad';
      case 'production':
        return 'Výroba';
         case 'rezijny':
        return 'Režijný materiál';
      case 'retail':
        return 'Maloobchod';
      default:
        return category;
    }
  }

  PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return PdfColors.orange;
      case 'approved':
        return PdfColors.green;
      case 'rejected':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Na schválenie';
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      default:
        return status;
    }
  }
}

