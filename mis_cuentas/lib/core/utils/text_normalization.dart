
class TextNormalization {
  static const List<String> _platforms = [
    'PEDIDOSYA',
    'UBER',
    'RAPPI',
    'CABIFY',
    'DIDI',
  ];

  static String normalizeMerchant(String raw) {
    String norm = raw.toUpperCase();
    
    // 1. Platform Detection (Smart Grouping)
    // Remove spaces to handle "PEDIDOS YA" vs "PEDIDOSYA" matches
    String spaceless = norm.replaceAll(' ', '');
    for (var platform in _platforms) {
      if (spaceless.contains(platform)) {
        return platform; // Return just the platform name (e.g. "PEDIDOSYA")
      }
    }

    // 2. Standard Cleanup (if not a platform)
    // Remove common prefixes/suffixes using regex
    norm = norm.replaceAll(RegExp(r'\s+S\.?A\.?.*$'), ''); // SA, S.A.
    norm = norm.replaceAll(RegExp(r'\s+S\.?R\.?L\.?.*$'), ''); // SRL
    norm = norm.replaceAll(RegExp(r'\*+'), ' '); // Asterisks
    norm = norm.replaceAll(RegExp(r'[0-9]{4,}'), ''); // Long number sequences (like IDs in description)
    norm = norm.replaceAll(RegExp(r'\s+'), ' ').trim(); // Multiple spaces

    return norm;
  }

  static double parseAmount(String amountStr) {
     // Remove currency symbols and spaces, but keep hyphen for negatives
    String clean = amountStr.replaceAll(RegExp(r'[A-Za-z\$\s]'), '');
    
    // Check format: 1.234,56 (European/South American) vs 1,234.56 (US)
    // Heuristic: if last non-digit separator is comma, assume comma is decimal.
    int lastComma = clean.lastIndexOf(',');
    int lastDot = clean.lastIndexOf('.');

    if (lastComma > lastDot) {
      // 1.234,56 -> remove dots, replace comma with dot
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // 1,234.56 -> remove commas
      clean = clean.replaceAll(',', '');
    }
    
    return double.tryParse(clean) ?? 0.0;
  }
}
