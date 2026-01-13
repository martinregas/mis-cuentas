
import 'package:flutter_test/flutter_test.dart';
import 'package:mis_cuentas/core/models/transaction.dart';
import 'package:mis_cuentas/features/parsing/parsers/generic_regex_parser.dart';

void main() {
  group('GenericRegexParser', () {
    final parser = GenericRegexParser();

    test('Parses standard transaction line correctly', () {
      final text = "12/01/2025 SUPERMERCADO COTO 12.300,50";
      final txs = parser.parse(text, "test.pdf", 1);
      
      expect(txs.length, 1);
      expect(txs.first.merchantNorm, "SUPERMERCADO COTO");
      expect(txs.first.amount, 12300.50);
      expect(txs.first.date.day, 12);
      expect(txs.first.date.month, 1);
    });

    test('Parses US format correctly', () {
      final text = "01/12/25 AMAZON.COM 1,200.50 USD"; 
      // Note: parser date logic (dd/mm) might interpret 01/12 as 1st Dec or 12th Jan depending on locale, 
      // but code implements dd/mm. So 01/12/25 -> 1st Dec 2025.
      final txs = parser.parse(text, "test.pdf", 1);

      expect(txs.length, 1);
      expect(txs.first.merchantNorm, "AMAZON.COM");
      expect(txs.first.amount, 1200.50);
      expect(txs.first.currency, "USD");
    });
    
    test('Parses multiple lines', () {
        final text = """
        10/01 Farmacity 500,00
        Invalid Line Here
        11/01 Carrefour 1.500 ARS
        """;
        
        final txs = parser.parse(text, "test.pdf", 1);
        expect(txs.length, 2);
        expect(txs[0].merchantNorm, "FARMACITY");
        expect(txs[1].merchantNorm, "CARREFOUR");
    });
  });
}
