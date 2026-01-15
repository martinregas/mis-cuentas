import 'package:mis_cuentas/core/models/transaction.dart';
import '../../../core/utils/text_normalization.dart';
import '../statement_parser.dart';

class GaliciaParser implements StatementParser {
  // Regex to match: "13-10-25" ... "46.500,00"
  // ^\s*(\d{2}-\d{2}-\d{2})\s+(.+?)\s+(-?[\d\.]*,\d{2})\s*$
  // RELAXED regex to handle "Glued" text (e.g. "04-10-25* GUARAPO")
  // \s* instead of \s+ allowed after date
  // 1. Standard: "Date Desc Amount" (Single Line)
  // RELAXED regex to handle "Glued" text (e.g. "04-10-25* GUARAPO")
  static final RegExp _transactionLineRegex = RegExp(
    r'^\s*(\d{2}-\d{2}-\d{2})\s*(.+?)\s+(-?[\d\.]*,\d{2})\s*$',
  );

  // 2. Partial: "Date Desc" (Missing Amount)
  // Used for multi-line transactions (e.g. GUARAPO)
  static final RegExp _partialLineRegex = RegExp(
    r'^\s*(\d{2}-\d{2}-\d{2})\s*(.+)$',
  );

  // 3. Amount Only: "14.333,33" or "1.000,00"
  static final RegExp _amountOnlyRegex = RegExp(r'^\s*(-?[\d\.]*,\d{2})\s*$');

  final List<String> _blacklist = [
    'SALDO ANTERIOR',
    'SU PAGO EN PESOS',
    'SU PAGO EN DOLARES',
    'SU PAGO EN USD', // Common variant
    'TOTAL A PAGAR',
    'PAGO DE SERVICIOS',
    'DEBITO AUTOMATICO',
  ];

  String currentCurrency = 'ARS'; // Default to Pesos

  @override
  bool canParse(String fullText) {
    String upper = fullText.toUpperCase();
    return upper.contains('GALICIA') || upper.contains('30-50000173-5');
  }

  @override
  List<Transaction> parse(String text, String pdfName, int? pageNumber) {
    List<Transaction> transactions = [];
    List<String> lines = text.split('\n');
    currentCurrency = 'ARS'; // Reset state per file

    // 1. Attempt to find "Statement Date" (Cierre) to determine the Period
    DateTime? statementDate = _extractStatementDateFromText(lines);
    String? period; // YYYY-MM

    if (statementDate != null) {
      print("DEBUG: Found Statement Date: $statementDate");
      period =
          "${statementDate.year}-${statementDate.month.toString().padLeft(2, '0')}";
    } else {
      print(
        "DEBUG: Could not find Statement Date. Will infer from transactions.",
      );
    }

    print("DEBUG: Galicia Regex Parser processing ${lines.length} lines.");

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.trim().isEmpty) continue;

      // 1. Normalize line for Header Detection (remove multiple spaces)
      String upper = line.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

      // 2. Currency Section Detection
      if (upper.contains('CONSUMOS EN DOLARES') ||
          upper.contains('CONSUMOS EN DÓLARES') ||
          upper.contains('CONSUMOS EN U\$S')) {
        currentCurrency = 'USD';
        continue;
      }
      if (upper.contains('CONSUMOS EN PESOS') ||
          upper.contains('DETALLE DE LOS CONSUMOS')) {
        currentCurrency = 'ARS';
        continue;
      }

      // 3. Try Standard Match (Single Line)
      var match = _transactionLineRegex.firstMatch(line);
      if (match != null) {
        _addTransaction(
          transactions,
          match.group(1)!,
          match.group(2)!,
          match.group(3)!,
          currentCurrency,
          pdfName,
          pageNumber,
          period, // Pass period
        );
        continue;
      }

      // 4. Try Partial Match (Date + Desc only) -> Check next lines for Amount
      var partialMatch = _partialLineRegex.firstMatch(line);
      if (partialMatch != null) {
        String dateStr = partialMatch.group(1)!;
        String descRaw = partialMatch.group(2)!;

        String? foundAmountStr;

        // Peek Line + 1
        if (i + 1 < lines.length) {
          var nextLine = lines[i + 1];
          var amountMatch = _amountOnlyRegex.firstMatch(nextLine);
          if (amountMatch != null) {
            foundAmountStr = amountMatch.group(1);
            i += 1; // Consume next line
          } else {
            // Peek Line + 2 (sometimes there is an ID in between)
            if (i + 2 < lines.length) {
              var secondLine = lines[i + 2];
              var amountMatch2 = _amountOnlyRegex.firstMatch(secondLine);
              if (amountMatch2 != null) {
                foundAmountStr = amountMatch2.group(1);
                i += 2; // Consume next 2 lines
                // descRaw += " " + nextLine.trim(); // Optional: merge ID
              }
            }
          }
        }

        if (foundAmountStr != null) {
          print(
            "DEBUG: Found Multi-line Transaction: $descRaw -> $foundAmountStr",
          );
          _addTransaction(
            transactions,
            dateStr,
            descRaw,
            foundAmountStr,
            currentCurrency,
            pdfName,
            pageNumber,
            period, // Pass period
          );
          continue;
        }
      }
    } // Close parsing loop

    // Failsafe: If StatementDate (header) failed, infer from the LATEST transaction date.
    // This ensures we group everything under one month (e.g. Dec-25) instead of splitting (Nov/Dec).
    if (period == null && transactions.isNotEmpty) {
      DateTime maxDate = transactions.first.date;
      for (var t in transactions) {
        if (t.date.isAfter(maxDate)) maxDate = t.date;
      }
      period = "${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}";
      print(
        "DEBUG: Statement Date not found. Inferred Period from Max Transaction Date: $period",
      );

      // Update all transactions in the list with this new period
      for (int i = 0; i < transactions.length; i++) {
        // Create copy with new period (since fields are final)
        transactions[i] = Transaction(
          id: transactions[i].id,
          date: transactions[i].date,
          descriptionRaw: transactions[i].descriptionRaw,
          merchantNorm: transactions[i].merchantNorm,
          amount: transactions[i].amount,
          currency: transactions[i].currency,
          pdfName: transactions[i].pdfName,
          pageNumber: transactions[i].pageNumber,
          period: period,
        );
      }
    }

    print(
      "DEBUG: Galicia Regex Parser found ${transactions.length} transactions. Final Period: $period",
    );
    return transactions;
  }

  void _addTransaction(
    List<Transaction> list,
    String dateStr,
    String desc,
    String amountStr,
    String currency,
    String pdfName,
    int? pageNumber,
    String? forcedPeriod,
  ) {
    if (_isBlacklisted(desc)) return;

    String cleanAmount = amountStr.replaceAll('.', '').replaceAll(',', '.');
    double amount;
    try {
      amount = double.parse(cleanAmount);
    } catch (e) {
      return;
    }

    DateTime? date = _parseDate(dateStr);
    if (date == null) return;

    // Force USD logic
    String upperDesc = desc.toUpperCase();
    String finalCurrency = currency;
    if (upperDesc.contains('USD') || upperDesc.contains('U\$S')) {
      finalCurrency = 'USD';
    }

    // Determine Period: Use Forced if available, else derive from date
    String finalPeriod =
        forcedPeriod ?? "${date.year}-${date.month.toString().padLeft(2, '0')}";

    list.add(
      Transaction(
        date: date,
        descriptionRaw: desc.trim(),
        merchantNorm: TextNormalization.normalizeMerchant(desc),
        amount: amount,
        currency: finalCurrency,
        pdfName: pdfName,
        pageNumber: pageNumber,
        period: finalPeriod,
      ),
    );
  }

  bool _isBlacklisted(String description) {
    String upper = description.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    for (var b in _blacklist) {
      if (upper.contains(b)) return true;
    }
    return false;
  }

  DateTime? _parseDate(String dateStr) {
    try {
      var parts = dateStr.split('-');
      if (parts.length != 3) return null;
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]) + 2000;
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  DateTime? _extractStatementDateFromText(List<String> lines) {
    int limit = lines.length < 100 ? lines.length : 100;

    RegExp dateReg = RegExp(r"(\d{2}-\w{3}-\d{2})"); // 24-Dic-25
    RegExp dateRegNum = RegExp(r"(\d{2}/\d{2}/\d{2})"); // 24/12/25
    RegExp dateRegDash = RegExp(r"(\d{2}-\d{2}-\d{2})"); // 24-12-25

    // Specific Regex for the "Timeline" line seen in logs: "20-Nov-25 01-Dic-25 24-Dic-25"
    // We want the 3rd date (Cierre Actual)
    RegExp threeDatesReg = RegExp(
      r"(\d{2}-\w{3}-\d{2})\s+(\d{2}-\w{3}-\d{2})\s+(\d{2}-\w{3}-\d{2})",
    );

    for (int i = 0; i < limit; i++) {
      String line = lines[i];
      String upper = line.toUpperCase();

      // 1. Check for the Triple Date Line (Timeline)
      var tripleMatch = threeDatesReg.firstMatch(line);
      if (tripleMatch != null) {
        // Group 3 is Cierre Actual
        print(
          "DEBUG: Found Triple Date Line. extracting Cierre Actual: ${tripleMatch.group(3)}",
        );
        return _parseHeaderDate(tripleMatch.group(3)!);
      }

      // 2. Check for explicit labels
      if (upper.contains("CIERRE ACTUAL") ||
          upper.contains("CIERRE") ||
          upper.contains("VTO.") ||
          upper.contains("VENCIMIENTO")) {
        var match =
            dateReg.firstMatch(line) ??
            dateRegNum.firstMatch(line) ??
            dateRegDash.firstMatch(line);
        if (match != null) {
          return _parseHeaderDate(match.group(1)!);
        }
        if (i + 1 < lines.length) {
          String nextLine = lines[i + 1];
          var matchNext =
              dateReg.firstMatch(nextLine) ??
              dateRegNum.firstMatch(nextLine) ??
              dateRegDash.firstMatch(nextLine);
          if (matchNext != null) return _parseHeaderDate(matchNext.group(1)!);
        }
      }
    }
    return null;
  }

  DateTime? _parseHeaderDate(String dateStr) {
    try {
      String clean = dateStr.replaceAll('/', '-');
      // Fix potential spacing issues "24 -Dic- 25" ? Unlikely with the regex.

      if (RegExp(r'[a-zA-Z]').hasMatch(clean)) {
        const months = {
          'ENE': '01',
          'FEB': '02',
          'MAR': '03',
          'ABR': '04',
          'MAY': '05',
          'JUN': '06',
          'JUL': '07',
          'AGO': '08',
          'SEP': '09',
          'OCT': '10',
          'NOV': '11',
          'DIC': '12',
        };
        // Handle "24-Dic-25" case-insensitively
        String upper = clean.toUpperCase();
        for (var entry in months.entries) {
          if (upper.contains(entry.key)) {
            String keyPart = "";
            // Find the exact substring to replace to preserve existing format structure if needed,
            // but simpler to just split.
            var parts = clean.split('-');
            if (parts.length == 3) {
              clean = "${parts[0]}-${entry.value}-${parts[2]}";
            }
            break;
          }
        }
      }
      var parts = clean.split('-');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]) + 2000;
      return DateTime(year, month, day);
    } catch (e) {
      print("DEBUG: Failed to parse header date: $dateStr -> $e");
      return null;
    }
  }

  @override
  DateTime? extractStatementDate(String text) {
    return _extractStatementDateFromText(text.split('\n'));
  }
}
