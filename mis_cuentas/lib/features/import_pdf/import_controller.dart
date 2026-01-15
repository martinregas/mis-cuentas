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
import '../../features/extraction/ocr_extraction_service.dart';
import '../audit/audit_engine.dart';
import '../transactions/transaction_list_screen.dart';

final importControllerProvider =
    NotifierProvider<ImportController, AsyncValue<void>>(() {
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
        allowMultiple: true, // Multi-selection enabled
      );

      if (result != null) {
        int successCount = 0;
        int failCount = 0;
        List<String> errors = [];

        // Iterate over ALL selected files
        for (var platformFile in result.files) {
          String? path = platformFile.path;
          if (path != null) {
            try {
              print("Multi-Import: Processing ${p.basename(path)}...");
              await importPdf(File(path));
              successCount++;
            } catch (e) {
              print("Multi-Import: Failed to import ${p.basename(path)}: $e");
              failCount++;
              errors.add("${p.basename(path)}: $e");
            }
          }
        }

        print(
          "Multi-Import Completed. Success: $successCount, Fail: $failCount",
        );

        if (failCount > 0 && successCount == 0) {
          throw Exception(
            "Failed to import any files. Errors: ${errors.join(', ')}",
          );
        }

        state = const AsyncValue.data(null);
      } else {
        // Cancelled
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> pickAndImportFolder() async {
    try {
      state = const AsyncValue.loading();

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final dir = Directory(selectedDirectory);
        List<FileSystemEntity> files = dir.listSync();
        List<File> pdfFiles = files
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.pdf')
            .toList();

        if (pdfFiles.isEmpty) {
          throw Exception("No PDF files found in selected folder.");
        }

        int successCount = 0;
        int failCount = 0;
        List<String> errors = [];

        for (var file in pdfFiles) {
          try {
            print("Bulk Import: Processing ${p.basename(file.path)}...");
            await importPdf(file);
            successCount++;
          } catch (e) {
            print("Bulk Import: Failed to import ${p.basename(file.path)}: $e");
            failCount++;
            errors.add("${p.basename(file.path)}: $e");
          }
        }

        // We can't easily return a complex object in AsyncValue<void>,
        // but we can throw if everything failed, or print the result.
        //Ideally we would show a dialog, but for now let's just log and set success state.
        print(
          "Bulk Import Completed. Success: $successCount, Fail: $failCount",
        );

        if (failCount > 0 && successCount == 0) {
          throw Exception(
            "Failed to import any files. Errors: ${errors.join(', ')}",
          );
        }

        state = const AsyncValue.data(null);
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

      // 1. Extract Text (with positions for Galicia)
      String text = await extractionService.extractText(file);
      print("DEBUG: Extracted text length: ${text.length}");
      print("DEBUG: First 500 chars: ${text.take(500)}");

      if (text.trim().isEmpty) {
        throw Exception("No text found in PDF. Is it scanned?");
      }

      // 2. Parse (Auto-detect strategy)
      StatementParser parser;
      List<Transaction> transactions;

      // Instantiate potential parsers
      final galiciaParser = GaliciaParser();
      final genericParser = GenericRegexParser();

      if (galiciaParser.canParse(text)) {
        print(
          "DEBUG: Detected Galicia Bank Statement (via canParse) - using Regex Parser",
        );
        parser = galiciaParser;
        transactions = parser.parse(text, p.basename(file.path), null);
      } else {
        print("DEBUG: Using Generic Parser");
        parser = genericParser;
        transactions = parser.parse(text, p.basename(file.path), null);
      }

      // Check for Duplicates by Statement Date
      DateTime? stmtDate = parser.extractStatementDate(text);
      print("DEBUG: Extracted Statement Date: $stmtDate");

      if (stmtDate != null) {
        List<PdfImport> existingImports = await db.getImports();
        bool isDuplicate = existingImports.any(
          (imp) =>
              imp.statementDate != null &&
              imp.statementDate!.month == stmtDate.month &&
              imp.statementDate!.year == stmtDate.year,
        );

        if (isDuplicate) {
          throw Exception(
            "¡Ya existe un resumen importado para ${stmtDate.month}/${stmtDate.year}!",
          );
        }
      }

      String filename = p.basename(file.path);

      if (transactions.isEmpty) {
        throw Exception("No transactions found in text. Check debug output.");
      }

      // 3. Save Import Record
      PdfImport pdfImport = PdfImport(
        fileName: filename,
        importDate: DateTime.now(),
        path: file.path,
        statementDate: stmtDate,
      );
      await db.insertImport(pdfImport);

      // Determine Period (e.g. "2025-10")
      String? period;
      if (stmtDate != null) {
        period =
            "${stmtDate.year}-${stmtDate.month.toString().padLeft(2, '0')}";
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
          period: period,
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
          period: txWithPeriod.period,
        );
        newSavedTransactions.add(saved);
      }

      // 5. Audit
      // Note: we need to cast to List<Transaction> because sometimes dynamic inference fails
      List<Transaction> fullHistory = await db.getTransactions();

      List<Case> anomalies = AuditEngine.audit(
        newSavedTransactions,
        fullHistory,
      );

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
