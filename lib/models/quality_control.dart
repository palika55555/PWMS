class QualityControl {
  final String id;
  final String batchId;
  final String testType; // strength, resistance, dimensions, etc.
  final String testName;
  final double? resultValue;
  final String? resultText;
  final bool passed;
  final DateTime? testedAt;
  final String? testedBy;
  final String? notes;
  final bool synced;

  QualityControl({
    required this.id,
    required this.batchId,
    required this.testType,
    required this.testName,
    this.resultValue,
    this.resultText,
    this.passed = false,
    this.testedAt,
    this.testedBy,
    this.notes,
    this.synced = false,
  });

  factory QualityControl.fromJson(Map<String, dynamic> json) {
    return QualityControl(
      id: json['id'] as String,
      batchId: json['batch_id'] as String,
      testType: json['test_type'] as String,
      testName: json['test_name'] as String,
      resultValue: json['result_value'] != null
          ? (json['result_value'] as num).toDouble()
          : null,
      resultText: json['result_text'] as String?,
      passed: json['passed'] == 1 || json['passed'] == true,
      testedAt: json['tested_at'] != null
          ? DateTime.parse(json['tested_at'])
          : null,
      testedBy: json['tested_by'] as String?,
      notes: json['notes'] as String?,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'test_type': testType,
      'test_name': testName,
      'result_value': resultValue,
      'result_text': resultText,
      'passed': passed ? 1 : 0,
      'tested_at': testedAt?.toIso8601String(),
      'tested_by': testedBy,
      'notes': notes,
      'synced': synced ? 1 : 0,
    };
  }

  QualityControl copyWith({
    String? id,
    String? batchId,
    String? testType,
    String? testName,
    double? resultValue,
    String? resultText,
    bool? passed,
    DateTime? testedAt,
    String? testedBy,
    String? notes,
    bool? synced,
  }) {
    return QualityControl(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      testType: testType ?? this.testType,
      testName: testName ?? this.testName,
      resultValue: resultValue ?? this.resultValue,
      resultText: resultText ?? this.resultText,
      passed: passed ?? this.passed,
      testedAt: testedAt ?? this.testedAt,
      testedBy: testedBy ?? this.testedBy,
      notes: notes ?? this.notes,
      synced: synced ?? this.synced,
    );
  }
}

class DefectivePiece {
  final String id;
  final String batchId;
  final int quantity;
  final String reason;
  final DateTime? recordedAt;
  final String? recordedBy;
  final bool synced;

  DefectivePiece({
    required this.id,
    required this.batchId,
    required this.quantity,
    required this.reason,
    this.recordedAt,
    this.recordedBy,
    this.synced = false,
  });

  factory DefectivePiece.fromJson(Map<String, dynamic> json) {
    return DefectivePiece(
      id: json['id'] as String,
      batchId: json['batch_id'] as String,
      quantity: json['quantity'] as int,
      reason: json['reason'] as String,
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'])
          : null,
      recordedBy: json['recorded_by'] as String?,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'quantity': quantity,
      'reason': reason,
      'recorded_at': recordedAt?.toIso8601String(),
      'recorded_by': recordedBy,
      'synced': synced ? 1 : 0,
    };
  }
}

