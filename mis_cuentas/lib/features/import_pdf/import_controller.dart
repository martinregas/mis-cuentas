
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/models/transaction.dart';
import '../../core/models/pdf_import.dart';
import '../../core/models/case.dart';
import '../../core/utils/extensions.dart';
import '../../core/providers.dart';
import '../../features/parsing/statement_parser.dart';
import '../../features/parsing/parsers/generic_regex_parser.dart';
import '../../features/parsing/parsers/galicia_parser.dart';
import '../audit/audit_engine.dart';
import '../transactions/transaction_list_screen.dart';

final importControllerProvider = NotifierProvider<ImportController, AsyncValue<void>>(() {
  return ImportController();
});

class ImportController extends Notifier<AsyncValue<void>> {

  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> pickAndImportPdf() async {
    try {
      state = const AsyncValue.loading();
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        String? path = result.files.single.path;
        if (path != null) {
          await importPdf(File(path));
        }
      } else {
        // Cancelled
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importPdf(File file) async {
    try {
      state = const AsyncValue.loading();
      
      final extractionService = ref.read(pdfExtractionServiceProvider);
      // Parser is selected dynamically below based on content
      final db = ref.read(databaseHelperProvider);

      // 1. Extract Text
      String text = await extractionService.extractText(file);
      print("DEBUG: Extracted text length: ${text.length}");
      print("DEBUG: First 500 chars: ${text.take(500)}");

      if (text.trim().isEmpty) {
        throw Exception("No text found in PDF. Is it scanned?");
      }
      
      // 2. Parse (Auto-detect strategy)
      StatementParser parser;
      if (text.toLowerCase().contains('galicia')) {
         print("DEBUG: Detected Galicia Bank Statement");
         parser = GaliciaParser();
      } else {
         print("DEBUG: Using Generic Parser");
         parser = GenericRegexParser();
      }

      // Check for Duplicates by Statement Date
      DateTime? stmtDate = parser.extractStatementDate(text);
      print("DEBUG: Extracted Statement Date: $stmtDate");

      if (stmtDate != null) {
        List<PdfImport> existingImports = await db.getImports();
        bool isDuplicate = existingImports.any((imp) => 
          imp.statementDate != null && 
          imp.statementDate!.month == stmtDate.month && 
          imp.statementDate!.year == stmtDate.year
        );

         if (isDuplicate) {
           throw Exception("¡Ya existe un resumen importado para ${stmtDate.month}/${stmtDate.year}!");
         }
      }

      String filename = p.basename(file.path);
      List<Transaction> transactions = parser.parse(text, filename, null);
      
      if (transactions.isEmpty) {
          throw Exception("No transactions found in text. Check debug output.");
      }

      // 3. Save Import Record
      PdfImport pdfImport = PdfImport(
        fileName: filename, 
        importDate: DateTime.now(), 
        path: file.path,
        statementDate: stmtDate
      );
      await db.insertImport(pdfImport);

      // Determine Period (e.g. "2025-10")
      String? period;
      if (stmtDate != null) {
        period = "${stmtDate.year}-${stmtDate.month.toString().padLeft(2, '0')}";
      }

      // 4. Save Transactions & Keep track of clean objects with IDs
      List<Transaction> newSavedTransactions = [];
      for (var tx in transactions) {
        // Create a copy with the period assigned
        Transaction txWithPeriod = Transaction(
          date: tx.date,
          descriptionRaw: tx.descriptionRaw,
          merchantNorm: tx.merchantNorm,
          amount: tx.amount,
          currency: tx.currency,
          pdfName: tx.pdfName,
          pageNumber: tx.pageNumber,
          period: period
        );

        int id = await db.insertTransaction(txWithPeriod);
         Transaction saved = Transaction(
             id: id,
             date: txWithPeriod.date,
             descriptionRaw: txWithPeriod.descriptionRaw,
             merchantNorm: txWithPeriod.merchantNorm,
             amount: txWithPeriod.amount,
             currency: txWithPeriod.currency,
             pdfName: txWithPeriod.pdfName,
             pageNumber: txWithPeriod.pageNumber,
             period: txWithPeriod.period
         );
         newSavedTransactions.add(saved);
      }
      
      // 5. Audit
      // Note: we need to cast to List<Transaction> because sometimes dynamic inference fails
      List<Transaction> fullHistory = await db.getTransactions();

      List<Case> anomalies = AuditEngine.audit(newSavedTransactions, fullHistory);

      // 6. Save Cases
      for (var anomaly in anomalies) {
        await db.insertCase(anomaly);
      }
      
      // Refresh Providers to update UI
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allPeriodsProvider);

      state = const AsyncValue.data(null);
      
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
