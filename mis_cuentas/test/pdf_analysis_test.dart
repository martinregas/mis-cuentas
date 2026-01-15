import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Analyze PDF Y-Coordinates', () async {
    // Files are in root
    final files = [
      'RESUMEN_VISA23_10_2025pdf.pdf',
      '34b307ca-ded0-4100-bb7c-a5c23e77ad38.pdf'
    ];

    for (String filename in files) {
      final file = File(filename);
      if (!file.existsSync()) {
        print('File NOT found: $filename');
        continue;
      }

      print('\n\n=== Analyzing $filename ===');
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      List<TextLine> textLines = PdfTextExtractor(document).extractTextLines();
      
      List<SimpleWord> allWords = [];
      for (TextLine line in textLines) {
        for (TextWord word in line.wordCollection) {
          allWords.add(SimpleWord(word.text, word.bounds.left, word.bounds.top));
        }
      }
      
      // Sort by Y
      allWords.sort((a, b) {
        int yComp = a.y.compareTo(b.y);
        if (yComp != 0) return yComp;
        return a.x.compareTo(b.x);
      });
      
      if (allWords.isEmpty) continue;
      
      double currentLineY = allWords.first.y;
      print('Line at Y=${currentLineY.toStringAsFixed(2)}: ${allWords.first.text}');
      
      for (int i = 1; i < allWords.length; i++) {
        SimpleWord word = allWords[i];
        double diff = (word.y - currentLineY).abs();
        
        // Tolerance analysis
        if (diff > 0.0 && diff < 5.0) {
          print('  -> Delta Y: ${diff.toStringAsFixed(4)} | Word: "${word.text}" at Y=${word.y.toStringAsFixed(2)}');
        }
        
        // Simulating 1.0 threshold
        if (diff > 1.0) {
          currentLineY = word.y;
          // Print new line start (just first few words to identify)
          print('Line at Y=${currentLineY.toStringAsFixed(2)}: ${word.text} ...');
        } else {
           // Same line
        }
      }
      
      document.dispose();
    }
  });
}

class SimpleWord {
  final String text;
  final double x;
  final double y;
  
  SimpleWord(this.text, this.x, this.y);
}
