class QualityCheck {
  final int? id;
  final int batchId;
  final String checkType;
  final String result; // 'passed', 'failed', 'warning'
  final double? value;
  final String? unit;
  final String? notes;
  final String checkedDate;
  final String? checkedBy;

  QualityCheck({
    this.id,
    required this.batchId,
    required this.checkType,
    required this.result,
    this.value,
    this.unit,
    this.notes,
    required this.checkedDate,
    this.checkedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'check_type': checkType,
      'result': result,
      'value': value,
      'unit': unit,
      'notes': notes,
      'checked_date': checkedDate,
      'checked_by': checkedBy,
    };
  }

  factory QualityCheck.fromMap(Map<String, dynamic> map) {
    return QualityCheck(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      checkType: map['check_type'] as String,
      result: map['result'] as String,
      value: map['value'] as double?,
      unit: map['unit'] as String?,
      notes: map['notes'] as String?,
      checkedDate: map['checked_date'] as String,
      checkedBy: map['checked_by'] as String?,
    );
  }
}

