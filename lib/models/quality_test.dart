class QualityTest {
  final int? id;
  final int batchId;
  final String testType; // compression, density, etc.
  final double? testValue;
  final String? testUnit;
  final String? testResult; // pass, fail
  final String testDate;
  final String? testedBy;
  final String? notes;
  final int synced;

  QualityTest({
    this.id,
    required this.batchId,
    required this.testType,
    this.testValue,
    this.testUnit,
    this.testResult,
    required this.testDate,
    this.testedBy,
    this.notes,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'test_type': testType,
      'test_value': testValue,
      'test_unit': testUnit,
      'test_result': testResult,
      'test_date': testDate,
      'tested_by': testedBy,
      'notes': notes,
      'synced': synced,
    };
  }

  factory QualityTest.fromMap(Map<String, dynamic> map) {
    return QualityTest(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      testType: map['test_type'] as String,
      testValue: (map['test_value'] as num?)?.toDouble(),
      testUnit: map['test_unit'] as String?,
      testResult: map['test_result'] as String?,
      testDate: map['test_date'] as String,
      testedBy: map['tested_by'] as String?,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
    );
  }
}






