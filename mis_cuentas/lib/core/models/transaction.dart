
class Transaction {
  final int? id;
  final DateTime date;
  final String descriptionRaw;
  final String merchantNorm;
  final double amount;
  final String currency;
  final String pdfName;
  final int? pageNumber;
  final String? period; // Format: YYYY-MM

  Transaction({
    this.id,
    required this.date,
    required this.descriptionRaw,
    required this.merchantNorm,
    required this.amount,
    required this.currency,
    required this.pdfName,
    this.pageNumber,
    this.period,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'descriptionRaw': descriptionRaw,
      'merchantNorm': merchantNorm,
      'amount': amount,
      'currency': currency,
      'pdfName': pdfName,
      'pageNumber': pageNumber,
      'period': period,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      date: DateTime.parse(map['date']),
      descriptionRaw: map['descriptionRaw'],
      merchantNorm: map['merchantNorm'],
      amount: map['amount'],
      currency: map['currency'],
      pdfName: map['pdfName'],
      pageNumber: map['pageNumber'],
      period: map['period'],
    );
  }
}
