
import 'package:flutter_test/flutter_test.dart';
import 'package:mis_cuentas/core/models/case.dart';
import 'package:mis_cuentas/core/models/transaction.dart';
import 'package:mis_cuentas/features/audit/audit_engine.dart';

void main() {
  group('AuditEngine', () {
    test('Detects duplicate transaction', () {
      final now = DateTime.now();
      final tx = Transaction(id: 1, date: now, descriptionRaw: "Test", merchantNorm: "TEST", amount: 100, currency: "ARS", pdfName: "p", pageNumber: 1);
      final history = [
        Transaction(id: 2, date: now.subtract(Duration(hours: 1)), descriptionRaw: "Test", merchantNorm: "TEST", amount: 100, currency: "ARS", pdfName: "p", pageNumber: 1),
        tx 
      ];

      final anomalies = AuditEngine.audit([tx], history);
      expect(anomalies.length, 1);
      expect(anomalies.first.type, CaseType.duplicate);
    });

    test('Detects high amount', () {
        final now = DateTime.now();
        // Avg is 100. New is 300 (> 2.5 * 100)
        final history = [
            Transaction(id: 2, date: now, merchantNorm: "TEST", amount: 100, currency: "ARS", descriptionRaw: "a", pdfName: "a"),
            Transaction(id: 3, date: now, merchantNorm: "TEST", amount: 100, currency: "ARS", descriptionRaw: "a", pdfName: "a"),
            Transaction(id: 4, date: now, merchantNorm: "TEST", amount: 100, currency: "ARS", descriptionRaw: "a", pdfName: "a"),
            // current
             Transaction(id: 1, date: now, merchantNorm: "TEST", amount: 300, currency: "ARS", descriptionRaw: "a", pdfName: "a"),
        ];
        
        final tx = history.last;
        final anomalies = AuditEngine.audit([tx], history);
        
        expect(anomalies.any((c) => c.type == CaseType.highAmount), true);
    });
  });
}
