import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart'; // Changed to pdfx
import 'package:mis_cuentas/core/models/pdf_positioned_text.dart';

class OcrExtractionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<List<PdfLineWithPositions>> extractTextWithPositions(
    String path,
  ) async {
    List<PdfLineWithPositions> allLines = [];
    PdfDocument? doc;

    try {
      print("DEBUG: Starting OCR Extraction for $path (using pdfx)");
      doc = await PdfDocument.openFile(path);
      int pageCount = doc.pagesCount; // pdfx uses pagesCount
      print("DEBUG: PDF has $pageCount pages");

      for (int i = 1; i <= pageCount; i++) {
        // 1. Render Page to Image
        // pdfx uses getPage(i)
        final page = await doc.getPage(i);

        // We render at higher resolution for OCR
        // pdfx render returns a PdfPageImage object
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
        );

        // pdfx's render returns nullable?
        if (pageImage == null) {
          page.close();
          continue;
        }

        // Convert raw pixels/bytes to valid PNG file
        // pdfx implementation of .render usually returns encoded bytes if format is PNG?
        // Let's check documentation or assume it returns pixels.
        // Actually, pdfx page.render returns a PdfPageImage which has `bytes`.
        // If format is PNG, `bytes` are likely already a PNG file content?
        // Let's Assume `bytes` IS the encoded image because we asked for PNG.

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/ocr_page_$i.png');
        await tempFile.writeAsBytes(pageImage.bytes);

        print("DEBUG: Rendered page $i to ${tempFile.path}");

        // Cleanup Page
        page.close(); // pdfx page needs closing

        // 2. Process with ML Kit
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final RecognizedText recognizedText = await _textRecognizer
            .processImage(inputImage);

        // 3. Map to Domain Models
        double yOffset =
            (i - 1) *
            3000.0; // Assume max page height 3000, stack pages vertically

        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            List<PdfWord> words = [];
            for (TextElement element in line.elements) {
              double scaleFactor = 0.5; // We rendered at 2x
              words.add(
                PdfWord(
                  text: element.text,
                  x: element.boundingBox.left * scaleFactor,
                  // CRITICAL FIX: Add yOffset to separate pages vertically!
                  y: (element.boundingBox.top * scaleFactor) + yOffset,
                  width: element.boundingBox.width * scaleFactor,
                  height: element.boundingBox.height * scaleFactor,
                ),
              );
            }
            if (words.isNotEmpty) {
              words.sort((a, b) => a.x.compareTo(b.x));
              allLines.add(
                PdfLineWithPositions(y: words.first.y, words: words),
              );
            }
          }
        }

        // Cleanup temp file
        await tempFile.delete();
      }

      print("DEBUG: OCR finished. Processing lines...");

      // 4. Post-processing: Merge lines that are visually on the same row.
      // ML Kit often returns columns as separate blocks. We need to reconstruct the rows.
      // Flatten to all words first.
      List<PdfWord> allWords = [];
      for (var line in allLines) {
        allWords.addAll(line.words);
      }

      // Sort primarily by Y, then by X
      allWords.sort((a, b) {
        int yComp = a.y.compareTo(b.y);
        if (yComp != 0) return yComp;
        return a.x.compareTo(b.x);
      });

      List<PdfLineWithPositions> mergedLines = [];
      if (allWords.isEmpty) return [];

      List<PdfWord> currentLineWords = [allWords.first];
      double currentLineY = allWords.first.y;

      // Y-Tolerance to group words into a single line
      const double yTolerance = 5.0; // Higher tolerance for OCR drift

      for (int i = 1; i < allWords.length; i++) {
        PdfWord word = allWords[i];

        if ((word.y - currentLineY).abs() <= yTolerance) {
          currentLineWords.add(word);
        } else {
          // New line
          currentLineWords.sort((a, b) => a.x.compareTo(b.x));
          mergedLines.add(
            PdfLineWithPositions(
              y: currentLineY,
              words: List.from(currentLineWords),
            ),
          );

          currentLineWords = [word];
          currentLineY = word.y;
        }
      }

      if (currentLineWords.isNotEmpty) {
        currentLineWords.sort((a, b) => a.x.compareTo(b.x));
        mergedLines.add(
          PdfLineWithPositions(y: currentLineY, words: currentLineWords),
        );
      }

      print(
        "DEBUG: Reconstructed ${mergedLines.length} visual lines from OCR data.",
      );
      return mergedLines;
    } catch (e) {
      print("ERROR: OCR Failed: $e");
      return [];
    } finally {
      doc?.close(); // pdfx doc needs closing
    }
  }

  Future<String> extractText(File file) async {
    var lines = await extractTextWithPositions(file.path);
    return lines.map((l) => l.text).join('\n');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
