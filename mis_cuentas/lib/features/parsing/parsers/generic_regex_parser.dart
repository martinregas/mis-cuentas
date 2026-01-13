
import 'package:intl/intl.dart';
import '../../../core/models/transaction.dart';
import '../../../core/utils/text_normalization.dart';
import '../statement_parser.dart';

class GenericRegexParser implements StatementParser {
  
  // Regex bits
  // Date: 
  static final RegExp _dateRegex = RegExp(r'^(\d{1,2}[/\-\.](?:\d{1,2}|[a-zA-Z]{3})[/\-\.]\d{2,4})$');
  
  // Amount: number with dots and commas. 
  // Allow negative sign at start
  static final RegExp _amountRegex = RegExp(r'^-?[\d\.,]+$');

  @override
  bool canParse(String fullText) {
    return true; 
  }

  @override
  List<Transaction> parse(String text, String pdfName, int? pageNumber) {
    List<Transaction> transactions = [];
    List<String> lines = text.split('\n');
    
    print("DEBUG: Token Parser starting on ${lines.length} lines.");

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Tokenize by spaces
      List<String> tokens = line.split(RegExp(r'\s+'));
      if (tokens.length < 3) continue; 

      // 1. Identify Date at Start (Check first 3 tokens just in case of markers like *)
      int dateIndex = -1;
      for (int i = 0; i < 3 && i < tokens.length; i++) {
        if (_dateRegex.hasMatch(tokens[i])) {
          dateIndex = i;
          break;
        }
      }

      if (dateIndex == -1) {
         // No date found at start of line
         continue;
      }

      DateTime? date = _parseDate(tokens[dateIndex]);
      if (date == null) continue;

      // 2. Identify Amount at End (Scan backwards)
      double amount = 0.0;
      String currency = 'ARS';
      int amountIndex = -1;

      for (int i = tokens.length - 1; i > dateIndex; i--) {
        String t = tokens[i];
        
        // Skip Currency words
        if (t == 'USD' || t == 'ARS' || t == '\$' || t == 'U\$S') {
           currency = (t == '\$' || t == 'ARS') ? 'ARS' : 'USD';
           continue;
        }

        // Is it a number?
        if (_amountRegex.hasMatch(t)) {
           // Heuristic: Is it a Receipt ID like 004073 or 701504?
           // Receipt IDs often start with 0 or are integers.
           // Amounts often have punctuation (.,) BUT logic can fail on "100,00".
           
           // If it's the LAST token (ignoring currency), prefer it as amount.
           // Unless we found an amount already.
           
           // Let's rely on TextNormalization.
           try {
             double val = TextNormalization.parseAmount(t);
             // If val is 0, might be garbage.
             // If val is integer like 215, it might be Branch. 
             // BUT "-6.816,18" is definitely amount.
             
             // If we haven't found an amount yet, take it.
             // If we construct a strict hierarchy:
             // - Value with decimal/thousand separator PREFERRED over plain integer.
             // - If plain integer, only accept if it's the right-most token.
             
             amount = val;
             amountIndex = i;
             break; 
           } catch(e) {}
        }
      }

      if (amountIndex == -1) {
         print("DEBUG: Skipped Line (Date found but no Amount): $line");
         continue;
      }

      // 3. Extract Description
      // Everything between Date token and Amount token
      List<String> descTokens = tokens.sublist(dateIndex + 1, amountIndex);
      String descRaw = descTokens.join(' ');
      
      String merchant = TextNormalization.normalizeMerchant(descRaw);
      
      try {
        transactions.add(Transaction(
          date: date,
          descriptionRaw: descRaw,
          merchantNorm: merchant,
          amount: amount,
          currency: currency,
          pdfName: pdfName,
          pageNumber: pageNumber,
        ));
      } catch (e) {
         print("DEBUG: Error adding transaction: $e");
      }
    }
    
    return transactions;
  }

  DateTime? _parseDate(String dateStr) {
    // Normalize separators
    dateStr = dateStr.replaceAll('-', '/').replaceAll('.', '/');
    List<String> parts = dateStr.split('/');
    
    if (parts.length < 2) return null;

    int day = int.tryParse(parts[0]) ?? 1;
    int year = DateTime.now().year;
    int month = 1;

    // Check if month is digits or text
    if (RegExp(r'^\d+$').hasMatch(parts[1])) {
      month = int.parse(parts[1]);
    } else {
      // Parse text month
      month = _monthReview(parts[1]);
    }

    if (parts.length > 2) {
      int y = int.tryParse(parts[2]) ?? 0;
      if (y < 100) year = 2000 + y;
      else year = y;
    }

    return DateTime(year, month, day);
  }

  int _monthReview(String monthStr) {
    String m = monthStr.toLowerCase();
    if (m.startsWith('ene') || m.startsWith('jan')) return 1;
    if (m.startsWith('feb')) return 2;
    if (m.startsWith('mar')) return 3;
    if (m.startsWith('abr') || m.startsWith('apr')) return 4;
    if (m.startsWith('may')) return 5;
    if (m.startsWith('jun')) return 6;
    if (m.startsWith('jul')) return 7;
    if (m.startsWith('ago') || m.startsWith('aug')) return 8;
    if (m.startsWith('sep') || m.startsWith('set')) return 9;
    if (m.startsWith('oct')) return 10;
    if (m.startsWith('nov')) return 11;
    if (m.startsWith('dic') || m.startsWith('dec')) return 12;
    return 1;
  }
  @override
  DateTime? extractStatementDate(String fullText) {
    return null; // Not supported for generic
  }
}
