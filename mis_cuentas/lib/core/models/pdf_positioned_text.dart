/// Represents a single word extracted from a PDF with its position
class PdfWord {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;

  const PdfWord({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'PdfWord(text: "$text", x: $x, y: $y)';
}

/// Represents a line of text from a PDF with positioned words
class PdfLineWithPositions {
  final double y;
  final List<PdfWord> words;

  const PdfLineWithPositions({
    required this.y,
    required this.words,
  });

  /// Get the full text of the line by concatenating words
  String get text => words.map((w) => w.text).join(' ');

  /// Get a word at approximately the given X position (with tolerance)
  PdfWord? getWordAtX(double targetX, {double tolerance = 20.0}) {
    for (final word in words) {
      if ((word.x - tolerance) <= targetX && targetX <= (word.x + word.width + tolerance)) {
        return word;
      }
    }
    return null;
  }

  @override
  String toString() => 'PdfLineWithPositions(y: $y, text: "$text")';
}
