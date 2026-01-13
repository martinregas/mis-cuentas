import 'package:mis_cuentas/core/models/transaction.dart';
import 'package:mis_cuentas/core/utils/text_normalization.dart';
import 'package:mis_cuentas/features/parsing/statement_parser.dart';
import 'package:mis_cuentas/core/utils/extensions.dart';

class GaliciaParser implements StatementParser {
  // Date: dd-mm-yy or dd-MMM-yy (e.g. 01-12-25 or 20-Nov-25)
  static final RegExp _dateRegex = RegExp(r'^(\d{1,2}[/\-\.](?:\d{1,2}|[a-zA-Z]{3})[/\-\.]\d{2,4})$');
  
  // Quota: 01/12 or 12/12 format (Strict)
  static final RegExp _quotaRegex = RegExp(r'^\d{1,2}/\d{1,2}$');

  // Receipt: Usually 6+ digits strictly numeric, e.g. 004073.
  // We use this to distinguish from "Branch 215" in description.
  static final RegExp _receiptRegex = RegExp(r'^\d{6,}$');

  // Amount: Must have punctuation if it's not a generic integer. 
  // But strictly, PDF amounts usually have 2 decimal places: "100,00", "5.865,00"
  // We'll require at least one dot or comma to be considered a valid amount candidate,
  // to differentiate from integers in description.
  static final RegExp _amountRegex = RegExp(r'^-?[\d\.,]+$');
  
  // Blacklist words to ignore (Payments, Balance, etc.)
  static const List<String> _blacklist = [
    'SU PAGO EN', 'SALDO ANTERIOR', 'TOTAL A PAGAR', 'PAGO MINIMO', 
    'DEBITO AUTOMATICO', 'IMPUESTO SELLOS', 'IVA RG', 'PERCEP', 'IMP PAIS', 'DB.RG'
    // Note: User might want to see Taxes (IVA/DB.RG)? 
    // User complaint was "Faltan un monton de gastos".
    // "IVA RG", "DB.RG" were visible in the screenshot, user didn't explicitly complain about them appearing,
    // explicitly complained about "SU PAGO EN PESOS".
    // I will filter "SU PAGO" and "SALDO". 
    // I will optionally filter Taxes if they are clutter, but for now let's keep taxes as they are technically expenses.
  ];

  @override
  bool canParse(String fullText) {
    return fullText.toLowerCase().contains('galicia');
  }

  @override
  List<Transaction> parse(String text, String pdfName, int? pageNumber) {
    List<Transaction> transactions = [];
    List<String> lines = text.split('\n');

    print("DEBUG: GaliciaParser (Strict) starting on ${lines.length} lines.");
    
    // Skip everything until we find the SECOND "FECHA" header
    // (First one is in CONSOLIDADO, second one is in DETALLE DEL CONSUMO)
    bool foundDetailSection = false;
    int fechaCount = 0;

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Check if we've reached the detail section
      if (!foundDetailSection) {
        String upperLine = line.toUpperCase();
        // Look for the header line with column names
        if (upperLine.contains('FECHA') && upperLine.contains('COMPROBANTE')) {
          fechaCount++;
          if (fechaCount == 2) {
            // This is the second FECHA header (DETALLE DEL CONSUMO section)
            foundDetailSection = true;
            print("DEBUG: Found second 'FECHA' header (DETALLE DEL CONSUMO), starting to parse transactions.");
          }
        }
        continue; // Skip all lines until we find the second header
      }

      // 1. Aggressive Token Spacing
      // Visually they look separated, but raw extraction might be merging them if columns are tight.
      // This regex forces a space between:
      // - Any Digit group
      // - FOLLOWED BY a Hyphen or Number
      // - That looks like an amount (contains comma/dot)
      // Example: "003347-6.816,18" -> "003347 -6.816,18"
      // Example: "00334710.000,00" -> "003347 10.000,00" (Risk of breaking large numbers? Unlikely for Receipt vs Amount)
      
      // Fix Negative Stuck: 003347-6.816
      line = line.replaceAllMapped(
          RegExp(r'(\d+)(-\d+[.,]\d+)'), 
          (Match m) => "${m.group(1)} ${m.group(2)}"
      );
      
      // Fix Positive Stuck: 00334711.399,00
      // If we see >3 digits followed by something starting with digit and containing dot/comma?
      // Safer: (\d{4,}) (\d+[.,]\d+)
      line = line.replaceAllMapped(
          RegExp(r'(\d{4,})(\d{1,3}[.,]\d+)'), 
          (Match m) => "${m.group(1)} ${m.group(2)}"
      );

      // Check for Date at start
      List<String> tokens = line.split(RegExp(r'\s+'));
      if (tokens.isEmpty) continue;
      
      if (!_dateRegex.hasMatch(tokens[0])) {
        // Not a transaction line (Header, Footer, etc.)
        // Debug: Print first few rejected lines to see if we are missing legit ones
        if (tokens[0].length > 5 && RegExp(r'\d').hasMatch(tokens[0])) {
           print("DEBUG: Rejected Line (Date mismatch): $line [Token0: '${tokens[0]}']");
        }
        continue;
      }
      
      // Check blacklist
      String fullLineUpper = line.toUpperCase();
      if (fullLineUpper.contains('SU PAGO EN') || fullLineUpper.contains('SALDO ANTERIOR')) {
         print("DEBUG: Ignoring Payment/Balance line: $line");
         continue; 
      }

      // 2. Strict Column Parsing
      // Expected Structure:
      // [Date] [Description Words...] [Quota?] [Receipt?] [Amount1?] [Amount2?]
      
      // 2. Strict Column Parsing
      // Expected Structure:
      // [Date] [Description Words...] [Quota?] [Receipt?] [Amount1?] [Amount2?]
      
      DateTime? date = _parseDate(tokens[0]);
      if (date == null) {
        // print("DEBUG: First token not a date: ${tokens[0]}");
        continue;
      }

      // Scan from RIGHT to find Amounts and Metadata
      List<String> trailingColumns = [];
      int cursor = tokens.length - 1;
      
      // Debug this line
      print("DEBUG: Processing Line: $line");
      print("DEBUG: Tokens: $tokens");
      
      while (cursor > 0) {
        String t = tokens[cursor];
        
        bool isQuota = _quotaRegex.hasMatch(t);
        bool isReceipt = _receiptRegex.hasMatch(t);
        bool isAmount = _isStrictAmount(t); 
        
        // Debug classification
        // print("DEBUG: Token '$t' -> Quota:$isQuota Receipt:$isReceipt Amount:$isAmount");
        
        if (isQuota || isReceipt || isAmount) {
           trailingColumns.insert(0, t); 
        } else {
           // Break on Description
           break;
        }
        cursor--;
      }
      
      print("DEBUG: Trailing Columns Identified: $trailingColumns");
      
      if (trailingColumns.isEmpty) {
        print("DEBUG: Skipped line (No trailing columns found)");
        continue;
      }
      
      List<double> amountsFound = [];
      for (var col in trailingColumns) {
         // Now we accept almost anything as amount if it passed the _isStrictAmount check (which is now loose)
         // BUT we must filter out Receipts/Quotas from being treated as amounts here.
         if (!_quotaRegex.hasMatch(col) && !_receiptRegex.hasMatch(col)) {
             try {
               amountsFound.add(TextNormalization.parseAmount(col));
             } catch(e) {
               print("DEBUG: Failed to parse amount '${col}'");
             }
         }
      }
      
      print("DEBUG: Amounts extracted: $amountsFound");

      if (amountsFound.isEmpty) {
         print("DEBUG: Skipped line (No valid amounts parsed)");
         continue;
      }
      
      // Logic for ARS vs USD
      double finalAmount = 0.0;
      String currency = 'ARS';

      if (amountsFound.length == 2) {
         // [Pesos, Dollars] assuming second is USD
         double ars = amountsFound[0];
         double usd = amountsFound[1];
         // Logic: if both exist, prioritize USD? Or check logic.
         // Let's assume the last one is USD.
         finalAmount = usd;
         currency = 'USD'; 
      } else {
         // 1 Amount found.
         finalAmount = amountsFound[0];
         currency = 'ARS'; 
         // Can we detect USD by regex in description? "USD" keyword?
         String fullLine = tokens.join(' ');
         if (fullLine.contains('USD')) {
            currency = 'USD';
         }
      }

      // Extract Description
      // From index 1 to cursor (inclusive)
      if (cursor < 1) {
         // Weird case: tokens[0] is date, cursor is 0? Means immediate amount?
         // "01-12-25 500,00" -> No description.
         print("DEBUG: Line with no description: $line");
         continue; 
      }
      
      String descRaw = tokens.sublist(1, cursor + 1).join(' ');
      String merchant = TextNormalization.normalizeMerchant(descRaw);

      transactions.add(Transaction(
        date: date,
        descriptionRaw: descRaw,
        merchantNorm: merchant,
        amount: finalAmount,
        currency: currency,
        pdfName: pdfName,
        pageNumber: pageNumber,
      ));
    }

    return transactions;
  }

  bool _isStrictAmount(String t) {
     // Must match basic regex (allow negatives)
     if (!_amountRegex.hasMatch(t)) return false;
     
     // CRITICAL: Must have punctuation (text-to-double logic handles 1.000 and 1,00)
     // To avoid capturing ID "004073" or "215", we require a separator.
     // Exception: "100" or "5000" (Round numbers).
     // Bank statements usually format with ",00".
     // "100,00" -> has comma.
     // "34,47" -> has comma.
     // "1.760.261,58" -> has dots and comma.
     // "215" (Branch) -> No separator.
     // "004073" (Receipt) -> No separator.
     
     return true;
     /*
     // Original Strict Check: Required punctuation.
     // This was too strict for amounts like "100" or "5000".
     // return t.contains('.') || t.contains(',');
     */
  }

  DateTime? _parseDate(String dateStr) {
    try {
      dateStr = dateStr.replaceAll('-', '/').replaceAll('.', '/');
      List<String> parts = dateStr.split('/');
      if (parts.length < 2) return null;

      int day = int.parse(parts[0]);
      int month = _monthReview(parts[1]);
      int year = DateTime.now().year;

      if (parts.length > 2) {
        int y = int.tryParse(parts[2]) ?? 0;
        if (y < 100) year = 2000 + y;
        else year = y;
      }
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  int _monthReview(String monthStr) {
    if (RegExp(r'^\d+$').hasMatch(monthStr)) return int.parse(monthStr);
    
    String m = monthStr.toLowerCase();
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
                    'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    
    for (int i=0; i<months.length; i++) {
      if (m.startsWith(months[i])) return (i % 12) + 1;
    }
    return 1;
  }
  
  @override
  DateTime? extractStatementDate(String fullText) {
    // Strategy 1: Look for "Cierre actual" in the ENTIRE text
    // The previous 1000 char limit might have been too aggressive.
    
    // Normalize newlines to spaces for easier regex
    String text = fullText.replaceAll('\n', ' ');
    
    // 1. Find anchor "Cierre actual" or "Cierre"
    int anchorIndex = text.toLowerCase().indexOf('cierre actual');
    if (anchorIndex == -1) {
       anchorIndex = text.toLowerCase().indexOf('cierre');
    }

    if (anchorIndex != -1) {
      // Find extraction near anchor
      final dateRegex = RegExp(r'(\d{1,2}[/\-\.](?:\d{1,2}|[a-zA-Z]{3,4})[/\-\.]\d{2,4})');
      final matches = dateRegex.allMatches(text);

      Match? bestMatch;
      int minDistance = 999999;

      for (var m in matches) {
         int dist = (m.start - anchorIndex).abs();
         if (dist < minDistance && dist < 500) { // Limit distance to be relevant
           minDistance = dist;
           bestMatch = m;
         }
      }

      if (bestMatch != null) {
        String dateStr = bestMatch.group(1)!;
        print("DEBUG: Found Date via 'Cierre' Strategy: $dateStr");
        return _parseDate(dateStr);
      }
    }

    // Strategy 2 (Backup): Look for "SU PAGO EN PESOS" or "SU PAGO EN USD"
    // Format: "06-10-25 SU PAGO EN PESOS ..."
    // The date is typically at the start of the line or just before the text.
    
    final paymentRegex = RegExp(r'(\d{2}-\d{2}-\d{2})\s+SU\s+PAGO\s+EN\s+(PESOS|USD)', caseSensitive: false);
    final paymentMatch = paymentRegex.firstMatch(text);
    
    if (paymentMatch != null) {
      String dateStr = paymentMatch.group(1)!;
      print("DEBUG: Found Date via 'PAGO' Strategy: $dateStr");
      return _parseDate(dateStr);
    }
    
    print("DEBUG: Could not extract Statement Date (strategies exhausted).");
    return null;
  }
}


