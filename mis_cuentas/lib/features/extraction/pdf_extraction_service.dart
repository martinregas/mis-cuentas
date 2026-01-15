
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/models/pdf_positioned_text.dart';

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

  /// Extracts text with position information for column-based parsing
  Future<List<PdfLineWithPositions>> extractTextWithPositions(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // 1. Flatten all words from all lines into a single list
      List<PdfWord> allWords = [];
      List<TextLine> textLines = PdfTextExtractor(document).extractTextLines();
      
      for (TextLine line in textLines) {
        for (TextWord word in line.wordCollection) {
          allWords.add(PdfWord(
            text: word.text,
            x: word.bounds.left,
            y: word.bounds.top,
            width: word.bounds.width,
            height: word.bounds.height,
          ));
        }
      }
      
      // 2. Sort words primarily by Y (top to bottom), secondarily by X (left to right)
      allWords.sort((a, b) {
        int yComp = a.y.compareTo(b.y);
        if (yComp != 0) return yComp;
        return a.x.compareTo(b.x);
      });
      
      // 3. Group words into lines based on Y proximity
      // Standard extraction without pre-filtering to ensure NO DATA LOSS.
      // We will handle noise filtering in the Parser.
      
      List<PdfLineWithPositions> resultLines = [];
      if (allWords.isEmpty) {
        document.dispose();
        return [];
      }

      List<PdfWord> currentLineWords = [allWords.first];
      double currentLineY = allWords.first.y;
      
      // Standard tolerance (2.0) to keep lines stable.
      // We rely on the Parser to split merged lines if necessary.
      const double yTolerance = 2.0;

      for (int i = 1; i < allWords.length; i++) {
        PdfWord word = allWords[i];
        
        if ((word.y - currentLineY).abs() <= yTolerance) {
          currentLineWords.add(word);
        } else {
          // New line
          currentLineWords.sort((a, b) => a.x.compareTo(b.x));
          
          resultLines.add(PdfLineWithPositions(
            y: currentLineY, 
            words: List.from(currentLineWords)
          ));
          
          currentLineWords = [word];
          currentLineY = word.y;
        }
      }
      
      // Add the last line
      if (currentLineWords.isNotEmpty) {
        currentLineWords.sort((a, b) => a.x.compareTo(b.x));
        resultLines.add(PdfLineWithPositions(
          y: currentLineY, 
          words: currentLineWords
        ));
      }
      
      document.dispose();
      return resultLines;
    } catch (e) {
      print("Error extracting text with positions: $e");
      return [];
    }
  }
}
