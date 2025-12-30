// ====================================================================
// PALLET LABEL MODEL - Flutter appka
// ====================================================================
// Model pre štítok palety s informáciami o debniacich tvarniciach PB-DT30

import 'package:intl/intl.dart';

class PalletLabel {
  /// Unikátne ID palety (pre QR kód)
  final String palletId;
  
  /// Kód produktu
  final String productCode;
  
  /// Názov produktu
  final String productName;
  
  /// Počet kusov na palete
  final int quantity;
  
  /// Celková hmotnosť palety v kg
  final double weight;
  
  /// Číslo šarže
  final String batchNumber;
  
  /// Dátum výroby
  final DateTime productionDate;
  
  /// Dátum balenia na paletu
  final DateTime? packedAt;
  
  /// Poznámky
  final String? notes;
  
  /// QR kód data
  final String qrData;

  const PalletLabel({
    required this.palletId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.weight,
    required this.batchNumber,
    required this.productionDate,
    this.packedAt,
    this.notes,
    required this.qrData,
  });

  /// Vytvorí PalletLabel pre PB-DT30 s postupným číslovaním
  factory PalletLabel.forPbDt30({
    required String batchNumber,
    required DateTime productionDate,
    DateTime? packedAt,
    String? notes,
    int? sequenceNumber, // Postupné číslovanie palety
  }) {
    final now = DateTime.now();
    final palletId = sequenceNumber != null 
        ? generatePalletId(sequenceNumber: sequenceNumber)
        : generatePalletId();
    
    final qrData = _generateQrData(
      palletId: palletId,
      productCode: 'PB-DT30',
      batchNumber: batchNumber,
      quantity: 30,
      packedAt: packedAt ?? now,
    );

    return PalletLabel(
      palletId: palletId,
      productCode: 'PB-DT30',
      productName: 'Debniaca tvarnica PB-DT30',
      quantity: 30,
      weight: 840.0,
      batchNumber: batchNumber,
      productionDate: productionDate,
      packedAt: packedAt ?? now,
      notes: notes,
      qrData: qrData,
    );
  }

  /// Vytvorí zoznam PalletLabel pre PB-DT30 s postupným číslovaním
  static List<PalletLabel> generatePalletLabelsForPbDt30({
    required String batchNumber,
    required DateTime productionDate,
    required int palletCount,
    DateTime? packedAt,
    String? notes,
    int startSequence = 1, // Počiatočné číslo postupnosti
  }) {
    final labels = <PalletLabel>[];
    final now = DateTime.now();
    
    for (int i = 0; i < palletCount; i++) {
      final sequenceNumber = startSequence + i;
      final palletId = generatePalletId(sequenceNumber: sequenceNumber);
      
      final qrData = _generateQrData(
        palletId: palletId,
        productCode: 'PB-DT30',
        batchNumber: batchNumber,
        quantity: 30,
        packedAt: packedAt ?? now,
      );

      labels.add(PalletLabel(
        palletId: palletId,
        productCode: 'PB-DT30',
        productName: 'Debniaca tvarnica PB-DT30',
        quantity: 30,
        weight: 840.0,
        batchNumber: batchNumber,
        productionDate: productionDate,
        packedAt: packedAt ?? now,
        notes: notes,
        qrData: qrData,
      ));
    }
    
    return labels;
  }

  /// Vygeneruje ID pre novú paletu s postupným číslovaním
  static String generatePalletId({int? sequenceNumber}) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    
    if (sequenceNumber != null) {
      // Použi zadané postupné číslo (formátované na 3 cifry)
      return 'PAL-$dateStr-${sequenceNumber.toString().padLeft(3, '0')}';
    } else {
      // Pôvodné generovanie s timestamp (fallback)
      final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
      final random = (now.second + now.millisecond).toString().padLeft(3, '0');
      return 'PAL-$dateStr-$timestamp-$random';
    }
  }

  /// Generuje QR data pre paletu
  static String _generateQrData({
    required String palletId,
    required String productCode,
    required String batchNumber,
    required int quantity,
    required DateTime packedAt,
  }) {
    return '{"t":"pallet","palletId":"$palletId","productCode":"$productCode","batchNumber":"$batchNumber","qty":$quantity,"packedAt":"${packedAt.toIso8601String()}"}';
  }

  /// Formátovaný dátum výroby
  String get formattedProductionDate {
    return '${productionDate.day.toString().padLeft(2, '0')}.${productionDate.month.toString().padLeft(2, '0')}.${productionDate.year}';
  }

  /// Formátovaný dátum balenia
  String get formattedPackedAt {
    if (packedAt == null) return '';
    return '${packedAt!.day.toString().padLeft(2, '0')}.${packedAt!.month.toString().padLeft(2, '0')}.${packedAt!.year}';
  }

  /// Formátovaná hmotnosť
  String get formattedWeight => '${weight.toStringAsFixed(1)} kg';

  /// Formátovaný popis
  String get displayDescription => '$productName ($quantity ks, $formattedWeight)';

  /// Konverzia na JSON
  Map<String, dynamic> toJson() {
    return {
      'palletId': palletId,
      'productCode': productCode,
      'productName': productName,
      'quantity': quantity,
      'weight': weight,
      'batchNumber': batchNumber,
      'productionDate': productionDate.toIso8601String(),
      'packedAt': packedAt?.toIso8601String(),
      'notes': notes,
      'qrData': qrData,
    };
  }

  /// Konverzia z JSON
  factory PalletLabel.fromJson(Map<String, dynamic> json) {
    return PalletLabel(
      palletId: json['palletId'] as String,
      productCode: json['productCode'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      weight: (json['weight'] as num).toDouble(),
      batchNumber: json['batchNumber'] as String,
      productionDate: DateTime.parse(json['productionDate'] as String),
      packedAt: json['packedAt'] != null 
          ? DateTime.parse(json['packedAt'] as String)
          : null,
      notes: json['notes'] as String?,
      qrData: json['qrData'] as String,
    );
  }

  @override
  String toString() {
    return 'PalletLabel(palletId: $palletId, productCode: $productCode, batchNumber: $batchNumber, quantity: $quantity)';
  }
}
