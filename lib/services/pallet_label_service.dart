// ====================================================================
// PALLET LABEL SERVICE - Flutter appka
// ====================================================================
// Služba pre generovanie PDF štítkov pre palety s debniacimi tvarnicami

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../models/pallet_label.dart';

class PalletLabelService {
  /// Vygeneruje PDF štítok pre paletu
  static Future<Uint8List> generatePalletLabelPdf(PalletLabel label) async {
    // Load Unicode fonts for Slovak characters
    pw.Font? ttf;
    pw.Font? ttfBold;
    
    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      print('⚠ Failed to load Regular font: $e');
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Regular.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          ttf = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
        }
      } catch (e2) {
        print('⚠ Failed to load Regular font from CDN: $e2');
      }
    }
    
    try {
      final fontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      ttfBold = pw.Font.ttf(fontData);
    } catch (e) {
      print('⚠ Failed to load Bold font: $e');
      try {
        final response = await http.get(
          Uri.parse('https://cdn.jsdelivr.net/gh/google/fonts@main/apache/opensans/static/OpenSans-Bold.ttf')
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          ttfBold = pw.Font.ttf(response.bodyBytes.buffer.asByteData());
        }
      } catch (e2) {
        print('⚠ Failed to load Bold font from CDN: $e2');
      }
    }
    
    if (ttf == null) {
      throw Exception('Nepodarilo sa načítať fonty pre PDF štítok');
    }
    
    final regularFont = ttf;
    final boldFont = ttfBold ?? ttf;
    
    final pdf = pw.Document();
    
    // Štítok palety - formát A6 (105 × 148 mm) alebo štandardný papier
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(10),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Hlavička
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Text(
                    'ŠTÍTOK PALETY',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 8),
                
                // Informácie o produkte
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        label.productName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Kód: ${label.productCode}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          font: regularFont,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                
                // Hlavné informácie
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'ID palety:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            label.palletId,
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Množstvo:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            '${label.quantity} ks',
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Hmotnosť:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            label.formattedWeight,
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                
                // Šarža a dátumy
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Šarža:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            label.batchNumber,
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Výroba:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              font: boldFont,
                            ),
                          ),
                          pw.Text(
                            label.formattedProductionDate,
                            style: pw.TextStyle(
                              fontSize: 8,
                              font: regularFont,
                            ),
                          ),
                        ],
                      ),
                      if (label.packedAt != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Balenie:',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                font: boldFont,
                              ),
                            ),
                            pw.Text(
                              label.formattedPackedAt,
                              style: pw.TextStyle(
                                fontSize: 8,
                                font: regularFont,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                
                // QR kód
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'QR KÓD PRE SKENOVANIE',
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          font: boldFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: label.qrData,
                        width: 60,
                        height: 60,
                      ),
                    ],
                  ),
                ),
                
                // Poznámky
                if (label.notes != null && label.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.yellow100,
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Poznámky:',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            font: boldFont,
                          ),
                        ),
                        pw.Text(
                          label.notes!,
                          style: pw.TextStyle(
                            fontSize: 6,
                            font: regularFont,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],
                
                pw.Spacer(),
                
                // Pät
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Text(
                    'PWMS - Warehouse Management System',
                    style: pw.TextStyle(
                      fontSize: 6,
                      font: regularFont,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    return await pdf.save();
  }
  
  /// Vygeneruje ID pre novú paletu s postupným číslovaním
  static String generatePalletId({int? sequenceNumber}) {
    return PalletLabel.generatePalletId(sequenceNumber: sequenceNumber);
  }
  
  /// Vygeneruje ID pre novú paletu s postupným číslovaním pre šaržu
  static String generatePalletIdForBatch(String batchNumber, int sequenceNumber) {
    return PalletLabel.generatePalletId(sequenceNumber: sequenceNumber);
  }
  
  /// Vytlačí štítok palety
  static Future<void> printPalletLabel(PalletLabel label) async {
    final pdf = await generatePalletLabelPdf(label);
    await Printing.layoutPdf(
      onLayout: (format) async => pdf,
      name: 'Štítok-palety-${label.palletId}.pdf',
    );
  }
  
  /// Zdieľa PDF štítok
  static Future<void> sharePalletLabel(PalletLabel label) async {
    final pdf = await generatePalletLabelPdf(label);
    await Printing.sharePdf(
      bytes: pdf,
      filename: 'Štítok-palety-${label.palletId}.pdf',
    );
  }
}
