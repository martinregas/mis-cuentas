
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionService {
  Future<String> extractText(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      // Enable layoutText to try and keep columns together in the same line
      // Standard: String text = PdfTextExtractor(document).extractText(layoutText: true);
      
      // Robust Solution: Manually extract lines and words to FORCE spaces between visual elements.
      // This prevents "20-12-25*DLO" merging issues.
      StringBuffer buffer = StringBuffer();
      List<TextLine> lines = PdfTextExtractor(document).extractTextLines();
      
      for (TextLine line in lines) {
        for (int i = 0; i < line.wordCollection.length; i++) {
          TextWord word = line.wordCollection[i];
          buffer.write(word.text);
          // Always add space after a word, unless it's the last word
          if (i < line.wordCollection.length - 1) {
             buffer.write(" ");
          }
        }
        buffer.writeln(); // End of line
      }
      
      String text = buffer.toString();
      document.dispose();
      return text;
    } catch (e) {
      print("Error extracting text: $e");
      return "";
    }
  }

  /// Extracts text per page. Returns a list where index is page number (0-based)
  Future<List<String>> extractTextPerPage(File file) async {
    try {
       final List<int> bytes = await file.readAsBytes();
       final PdfDocument document = PdfDocument(inputBytes: bytes);
       List<String> pages = [];
       // Syncfusion doesn't easily split text per page via extractText() raw call without loop
       // But extractText method extracts from all pages.
       // To do per page:
       for (int i = 0; i < document.pages.count; i++) {
           String pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
           pages.add(pageText);
       }
       document.dispose();
       return pages;
    } catch (e) {
      print("Error extracting text per page: $e");
      return [];
    }
  }
}
