import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  // Analyze both files
  await analyzeFile('RESUMEN_VISA23_10_2025pdf.pdf');
  print('-----------------------------------');
  await analyzeFile('34b307ca-ded0-4100-bb7c-a5c23e77ad38.pdf');
}

Future<void> analyzeFile(String filename) async {
  final file = File(filename);
  if (!file.existsSync()) {
    print('File not found: $filename');
    return;
  }

  print('Analyzing $filename...');
  final List<int> bytes = await file.readAsBytes();
  final PdfDocument document = PdfDocument(inputBytes: bytes);
  
  // Extract text lines
  List<TextLine> textLines = PdfTextExtractor(document).extractTextLines();
  
  // Flatten all words
  List<PdfWord> allWords = [];
  for (TextLine line in textLines) {
    for (TextWord word in line.wordCollection) {
      allWords.add(PdfWord(word.text, word.bounds.left, word.bounds.top));
    }
  }
  
  // Sort by Y
  allWords.sort((a, b) {
    int yComp = a.y.compareTo(b.y);
    if (yComp != 0) return yComp;
    return a.x.compareTo(b.x);
  });
  
  // Analyze vertical spacing
  if (allWords.isEmpty) return;
  
  double currentLineY = allWords.first.y;
  print('Line at Y=$currentLineY: ${allWords.first.text}');
  
  for (int i = 1; i < allWords.length; i++) {
    PdfWord word = allWords[i];
    double diff = (word.y - currentLineY).abs();
    
    // If difference is small but non-zero, it's interesting
    if (diff > 0.0 && diff < 10.0) {
      print('  -> Delta Y: ${diff.toStringAsFixed(4)} (Word: "${word.text}" at Y=${word.y})');
    }
    
    if (diff > 3.0) {
      // New line detected by our current threshold
      currentLineY = word.y;
      print('Line at Y=$currentLineY: ${word.text}');
    } else {
       print('    (Same line) ${word.text}');
    }
  }
  
  document.dispose();
}

class PdfWord {
  final String text;
  final double x;
  final double y;
  
  PdfWord(this.text, this.x, this.y);
}
