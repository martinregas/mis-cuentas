
class PdfImport {
  final int? id;
  final String fileName;
  final DateTime importDate;
  final String path;
  final DateTime? statementDate; // Extracted from PDF content

  PdfImport({
    this.id,
    required this.fileName,
    required this.importDate,
    required this.path,
    this.statementDate,
  });

   Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'importDate': importDate.toIso8601String(),
      'path': path,
      'statementDate': statementDate?.toIso8601String(),
    };
  }

  factory PdfImport.fromMap(Map<String, dynamic> map) {
    return PdfImport(
      id: map['id'],
      fileName: map['fileName'],
      importDate: DateTime.parse(map['importDate']),
      path: map['path'],
      statementDate: map['statementDate'] != null ? DateTime.parse(map['statementDate']) : null,
    );
  }
}
