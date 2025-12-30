// ====================================================================
// PRODUCT PALLET MODEL - Flutter appka
// ====================================================================
// Tento model reprezentuje produktovú paletu z backendu
// Je kompatibilný s ApiPalletItem z qr-web/lib/api.ts

/// Produktová paleta - jednotlivý záznam palety na sklade
/// Tento model zodpovedá ApiPalletItem z backendu
class ProductPallet {
  /// Unikátne ID v databáze
  final int id;
  
  /// Identifikátor palety (z QR kódu)
  final String palletId;
  
  /// Kód produktu
  final String productCode;
  
  /// Množstvo na palete
  final int quantity;
  
  /// Stav palety
  /// - "in_stock": paleta je na sklade
  /// - "issued": paleta bola vydaná
  final String status;
  
  /// Kedy bola paleta prvýkrát videná
  final DateTime firstSeenAt;
  
  /// Kedy bola paleta poslednýkrát videná
  final DateTime lastSeenAt;
  
  /// Surové dáta z posledného QR skenu
  final String? lastRaw;
  
  /// Zdroj poslednej zmeny (qr-web, app, atď.)
  final String? source;
  
  /// Kedy bol záznam vytvorený
  final DateTime createdAt;
  
  /// Kedy bol záznam naposledy aktualizovaný
  final DateTime updatedAt;

  const ProductPallet({
    required this.id,
    required this.palletId,
    required this.productCode,
    required this.quantity,
    required this.status,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.lastRaw,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Vytvorí ProductPallet z JSON
  factory ProductPallet.fromJson(Map<String, dynamic> json) {
    return ProductPallet(
      id: json['id'] as int,
      palletId: json['palletId'] as String,
      productCode: json['productCode'] as String,
      quantity: json['quantity'] as int,
      status: json['status'] as String,
      firstSeenAt: DateTime.parse(json['firstSeenAt'] as String),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      lastRaw: json['lastRaw'] as String?,
      source: json['source'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Konvertuje na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'palletId': palletId,
      'productCode': productCode,
      'quantity': quantity,
      'status': status,
      'firstSeenAt': firstSeenAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'lastRaw': lastRaw,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Vytvorí kópiu s aktualizovanými hodnotami
  ProductPallet copyWith({
    int? id,
    String? palletId,
    String? productCode,
    int? quantity,
    String? status,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    String? lastRaw,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductPallet(
      id: id ?? this.id,
      palletId: palletId ?? this.palletId,
      productCode: productCode ?? this.productCode,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastRaw: lastRaw ?? this.lastRaw,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check, či je paleta na sklade
  bool get isInStock => status == 'in_stock';

  /// Check, či je paleta vydaná
  bool get isIssued => status == 'issued';

  /// Formátovaný text pre zobrazenie stavu
  String get statusText {
    switch (status) {
      case 'in_stock':
        return 'Na sklade';
      case 'issued':
        return 'Vydaná';
      default:
        return status;
    }
  }

  /// Formátovaný popis palety
  String get displayTitle => '$palletId - $productCode';

  /// Formátovaný popis s množstvom
  String get displaySubtitle => 'Množstvo: $quantity | Stav: $statusText';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPallet &&
        other.id == id &&
        other.palletId == palletId &&
        other.productCode == productCode;
  }

  @override
  int get hashCode => id.hashCode ^ palletId.hashCode ^ productCode.hashCode;

  @override
  String toString() {
    return 'ProductPallet(id: $id, palletId: $palletId, productCode: $productCode, '
        'quantity: $quantity, status: $status)';
  }
}

/// Event palety - záznam o zmene stavu palety
/// Tento model zodpovedá ApiPalletEvent z backendu
class ProductPalletEvent {
  /// Unikátne ID eventu
  final int id;
  
  /// Identifikátor palety
  final String palletId;
  
  /// Kód produktu (môže byť null pri starých záznamoch)
  final String? productCode;
  
  /// Typ operácie
  /// - "receive": príjem na sklad
  /// - "issue": výdaj zo skladu
  final String mode;
  
  /// Množstvo (môže byť null)
  final int? quantity;
  
  /// Surové dáta z QR kódu
  final String? raw;
  
  /// Zdroj eventu
  final String? source;
  
  /// Kedy event nastal
  final DateTime createdAt;

  const ProductPalletEvent({
    required this.id,
    required this.palletId,
    this.productCode,
    required this.mode,
    this.quantity,
    this.raw,
    this.source,
    required this.createdAt,
  });

  /// Vytvorí ProductPalletEvent z JSON
  factory ProductPalletEvent.fromJson(Map<String, dynamic> json) {
    return ProductPalletEvent(
      id: json['id'] as int,
      palletId: json['palletId'] as String,
      productCode: json['productCode'] as String?,
      mode: json['mode'] as String,
      quantity: json['quantity'] as int?,
      raw: json['raw'] as String?,
      source: json['source'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Konvertuje na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'palletId': palletId,
      'productCode': productCode,
      'mode': mode,
      'quantity': quantity,
      'raw': raw,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check, či je to príjem
  bool get isReceive => mode == 'receive';

  /// Check, či je to výdaj
  bool get isIssue => mode == 'issue';

  /// Formátovaný text pre zobrazenie operácie
  String get modeText {
    switch (mode) {
      case 'receive':
        return 'Príjem';
      case 'issue':
        return 'Výdaj';
      default:
        return mode;
    }
  }

  /// Formátovaný popis eventu
  String get displayTitle => '$palletId - $modeText';

  /// Formátovaný popis s detailmi
  String get displaySubtitle {
    final parts = <String>[];
    if (productCode != null) parts.add('Produkt: $productCode');
    if (quantity != null) parts.add('Množstvo: $quantity');
    if (source != null) parts.add('Zdroj: $source');
    return parts.join(' | ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPalletEvent &&
        other.id == id &&
        other.palletId == palletId &&
        other.mode == mode;
  }

  @override
  int get hashCode => id.hashCode ^ palletId.hashCode ^ mode.hashCode;

  @override
  String toString() {
    return 'ProductPalletEvent(id: $id, palletId: $palletId, mode: $mode, '
        'productCode: $productCode, quantity: $quantity)';
  }
}

/// Súhrnné štatistiky palet
/// Tento model zodpovedá ApiSummary z backendu
class PalletSummary {
  /// Celkové štatistiky
  final PalletSummaryTotals totals;
  
  /// Štatistiky podľa produktov
  final List<PalletSummaryByProduct> byProduct;

  const PalletSummary({
    required this.totals,
    required this.byProduct,
  });

  /// Vytvorí PalletSummary z JSON
  factory PalletSummary.fromJson(Map<String, dynamic> json) {
    return PalletSummary(
      totals: PalletSummaryTotals.fromJson(json['totals'] as Map<String, dynamic>),
      byProduct: (json['byProduct'] as List)
          .map((item) => PalletSummaryByProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Konvertuje na JSON
  Map<String, dynamic> toJson() {
    return {
      'totals': totals.toJson(),
      'byProduct': byProduct.map((item) => item.toJson()).toList(),
    };
  }
}

/// Celkové štatistiky palet
class PalletSummaryTotals {
  /// Počet paliet na sklade
  final int inStockPallets;
  
  /// Počet vydaných paliet
  final int issuedPallets;
  
  /// Celkový počet paliet
  final int totalPallets;
  
  /// Množstvo na sklade
  final int inStockQty;
  
  /// Vydané množstvo
  final int issuedQty;
  
  /// Celkové množstvo
  final int totalQty;

  const PalletSummaryTotals({
    required this.inStockPallets,
    required this.issuedPallets,
    required this.totalPallets,
    required this.inStockQty,
    required this.issuedQty,
    required this.totalQty,
  });

  /// Vytvorí PalletSummaryTotals z JSON
  factory PalletSummaryTotals.fromJson(Map<String, dynamic> json) {
    return PalletSummaryTotals(
      inStockPallets: json['in_stock_pallets'] as int,
      issuedPallets: json['issued_pallets'] as int,
      totalPallets: json['total_pallets'] as int,
      inStockQty: json['in_stock_qty'] as int,
      issuedQty: json['issued_qty'] as int,
      totalQty: json['total_qty'] as int,
    );
  }

  /// Konvertuje na JSON
  Map<String, dynamic> toJson() {
    return {
      'in_stock_pallets': inStockPallets,
      'issued_pallets': issuedPallets,
      'total_pallets': totalPallets,
      'in_stock_qty': inStockQty,
      'issued_qty': issuedQty,
      'total_qty': totalQty,
    };
  }
}

/// Štatistiky podľa produktov
class PalletSummaryByProduct {
  /// Kód produktu
  final String productCode;
  
  /// Počet paliet na sklade
  final int inStockPallets;
  
  /// Počet vydaných paliet
  final int issuedPallets;
  
  /// Celkový počet paliet
  final int totalPallets;
  
  /// Množstvo na sklade
  final int inStockQty;
  
  /// Vydané množstvo
  final int issuedQty;
  
  /// Celkové množstvo
  final int totalQty;

  const PalletSummaryByProduct({
    required this.productCode,
    required this.inStockPallets,
    required this.issuedPallets,
    required this.totalPallets,
    required this.inStockQty,
    required this.issuedQty,
    required this.totalQty,
  });

  /// Vytvorí PalletSummaryByProduct z JSON
  factory PalletSummaryByProduct.fromJson(Map<String, dynamic> json) {
    return PalletSummaryByProduct(
      productCode: json['productCode'] as String,
      inStockPallets: json['inStockPallets'] as int,
      issuedPallets: json['issuedPallets'] as int,
      totalPallets: json['totalPallets'] as int,
      inStockQty: json['inStockQty'] as int,
      issuedQty: json['issuedQty'] as int,
      totalQty: json['totalQty'] as int,
    );
  }

  /// Konvertuje na JSON
  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'inStockPallets': inStockPallets,
      'issuedPallets': issuedPallets,
      'totalPallets': totalPallets,
      'inStockQty': inStockQty,
      'issuedQty': issuedQty,
      'totalQty': totalQty,
    };
  }

  /// Formátovaný popis produktu
  String get displayTitle => productCode;

  /// Formátovaný popis so štatistikami
  String get displaySubtitle {
    return 'Paliet: $totalPallets ($inStockPallets na sklade) | '
        'Množstvo: $totalQty ($inStockQty na sklade)';
  }
}
