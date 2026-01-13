
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database_helper.dart';
import '../features/extraction/pdf_extraction_service.dart';
import '../features/parsing/parsers/generic_regex_parser.dart';
import '../features/parsing/statement_parser.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final pdfExtractionServiceProvider = Provider<PdfExtractionService>((ref) {
  return PdfExtractionService();
});

final statementParserProvider = Provider<StatementParser>((ref) {
  return GenericRegexParser();
});
