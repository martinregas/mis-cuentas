
import '../../core/models/transaction.dart';

abstract class StatementParser {
  /// Returns true if this parser can handle the provided text block
  bool canParse(String fullText);

  /// Parses the text and returns a list of Transactions.
  /// [pdfName] and [pageNumber] are metadata to be attached to transactions.
  List<Transaction> parse(String text, String pdfName, int? pageNumber);

  /// Extracts the statement closing date from the full text
  DateTime? extractStatementDate(String fullText);
}
