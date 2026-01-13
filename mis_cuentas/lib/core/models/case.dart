
enum CaseType { duplicate, highAmount, subscription, unknown }
enum CaseStatus { active, ignored, approved }

class Case {
  final int? id;
  final int transactionId;
  final CaseType type;
  final String explanation;
  final CaseStatus status;

  Case({
    this.id,
    required this.transactionId,
    required this.type,
    required this.explanation,
    this.status = CaseStatus.active,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'type': type.index,
      'explanation': explanation,
      'status': status.index,
    };
  }

  factory Case.fromMap(Map<String, dynamic> map) {
    return Case(
      id: map['id'],
      transactionId: map['transactionId'],
      type: CaseType.values[map['type']],
      explanation: map['explanation'],
      status: CaseStatus.values[map['status']],
    );
  }
}
