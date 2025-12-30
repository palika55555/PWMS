// ====================================================================
// GENERATED LABELS MODEL - Flutter appka
// ====================================================================
// Model pre uloženie vygenerovaných štítkov pre neskoršie použitie

import 'package:intl/intl.dart';
import 'pallet_label.dart';

class GeneratedLabelsBatch {
  final String id;
  final String batchNumber;
  final DateTime createdAt;
  final List<PalletLabel> labels;
  final String? notes;
  final bool isSequential;
  final int startSequence;

  const GeneratedLabelsBatch({
    required this.id,
    required this.batchNumber,
    required this.createdAt,
    required this.labels,
    this.notes,
    required this.isSequential,
    required this.startSequence,
  });

  /// Vytvorí nový batch vygenerovaných štítkov
  factory GeneratedLabelsBatch.create({
    required String batchNumber,
    required List<PalletLabel> labels,
    String? notes,
    required bool isSequential,
    required int startSequence,
  }) {
    return GeneratedLabelsBatch(
      id: 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
      batchNumber: batchNumber,
      createdAt: DateTime.now(),
      labels: labels,
      notes: notes,
      isSequential: isSequential,
      startSequence: startSequence,
    );
  }

  /// Konverzia z JSON
  factory GeneratedLabelsBatch.fromJson(Map<String, dynamic> json) {
    return GeneratedLabelsBatch(
      id: json['id'] as String,
      batchNumber: json['batchNumber'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      labels: (json['labels'] as List)
          .map((label) => PalletLabel.fromJson(label as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      isSequential: json['isSequential'] as bool? ?? false,
      startSequence: json['startSequence'] as int? ?? 1,
    );
  }

  /// Konverzia na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchNumber': batchNumber,
      'createdAt': createdAt.toIso8601String(),
      'labels': labels.map((label) => label.toJson()).toList(),
      'notes': notes,
      'isSequential': isSequential,
      'startSequence': startSequence,
    };
  }

  /// Formátovaný dátum vytvorenia
  String get formattedCreatedAt {
    return DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
  }

  /// Formátovaný popis batchu
  String get displayDescription {
    final sequentialText = isSequential ? ' (postupné číslovanie)' : '';
    return 'Šarža $batchNumber$sequentialText • ${labels.length} štítkov';
  }

  /// Zistiť, či sú všetky štítky už vytlačené
  bool get allPrinted {
    // Tu by sa dalo pridať sledovanie stavu tlače
    return false;
  }

  /// Zistiť, či je batch starší ako zadaný počet dní
  bool isOlderThanDays(int days) {
    return DateTime.now().difference(createdAt).inDays > days;
  }

  @override
  String toString() {
    return 'GeneratedLabelsBatch(id: $id, batchNumber: $batchNumber, labels: ${labels.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedLabelsBatch && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
