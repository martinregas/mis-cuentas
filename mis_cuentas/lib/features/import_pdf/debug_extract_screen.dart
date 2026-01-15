import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mis_cuentas/core/providers.dart';
import 'package:mis_cuentas/core/models/transaction.dart';
import 'package:mis_cuentas/features/parsing/parsers/galicia_parser.dart';

import 'package:intl/intl.dart';

class DebugExtractScreen extends ConsumerStatefulWidget {
  final File file;

  const DebugExtractScreen({super.key, required this.file});

  @override
  ConsumerState<DebugExtractScreen> createState() => _DebugExtractScreenState();
}

class _DebugExtractScreenState extends ConsumerState<DebugExtractScreen> {
  List<Transaction>? _transactions;
  double _totalAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _extractAndParse();
  }

  Future<void> _extractAndParse() async {
    try {
      // Use the SAME provider as ImportController (Native PDF Extraction)
      final pdfService = ref.read(pdfExtractionServiceProvider);

      // 1. Extract Raw Text
      String text = await pdfService.extractText(widget.file);

      // 2. Parse using Galicia Parser
      // We assume it's Galicia for debugging, or we could use the generic one.
      // Let's use GaliciaParser since that's what we are debugging
      // 2. Parse using Galicia Parser
      final parser = GaliciaParser();
      final transactions = parser.parse(text, "debug.pdf", 1);

      // Calculate Totals Separately
      double totalARS = 0.0;
      double totalUSD = 0.0;
      for (var t in transactions) {
        if (t.currency == 'ARS') {
          totalARS += t.amount;
        } else {
          totalUSD += t.amount;
        }
      }

      print("DEBUG SCREEN: Total ARS: $totalARS");
      print("DEBUG SCREEN: Total USD: $totalUSD");

      print("--- START FULL TRANSACTION LIST (For Excel/Calc) ---");
      for (var t in transactions) {
        // Added Currency column to verify if detection works
        print(
          "DEBUG_LIST: ${DateFormat('yyyy-MM-dd').format(t.date)} ; ${t.currency} ; ${t.descriptionRaw} ; ${t.amount}",
        );
      }
      print("--- END FULL TRANSACTION LIST ---");

      // DIAGNOSTIC: Dump raw lines for missing items
      print("--- DIAGNOSTIC: RAW LINES CHECK ---");
      final rawLines = text.split('\n');
      for (var line in rawLines) {
        if (line.toUpperCase().contains('GUARAPO') ||
            line.toUpperCase().contains('PEDIDOSYA')) {
          print("RAW_DUMP: $line");
        }
        if (line.toUpperCase().contains('CONSUMOS EN DOLARES') ||
            line.toUpperCase().contains('CONSUMOS EN U\$S')) {
          print("RAW_HEADER_DUMP: $line");
        }
      }
      print("--- END DIAGNOSTIC ---");

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _totalAmount = totalARS; // Only show ARS total in simple UI
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error debugging: $e")));
      }
    }
  }

  void _printToConsole() {
    if (_transactions == null) return;
    print("--- START FULL TRANSACTION LIST (For Excel/Calc) ---");
    for (var t in _transactions!) {
      print(
        "DEBUG_LIST: ${DateFormat('yyyy-MM-dd').format(t.date)} ; ${t.descriptionRaw} ; ${t.amount}",
      );
    }
    print("--- END FULL TRANSACTION LIST ---");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("List printed to Terminal Console")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug Parser Output")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blueGrey.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Found: ${_transactions?.length ?? 0} items"),
                      Text(
                        "Total: \$${_totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                // Transaction List
                Expanded(
                  child: _transactions == null || _transactions!.isEmpty
                      ? const Center(child: Text("No transactions parsed."))
                      : ListView.builder(
                          itemCount: _transactions!.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions![index];
                            final isNegative = tx.amount < 0;
                            return ListTile(
                              dense: true,
                              leading: Text(
                                DateFormat('dd/MM').format(tx.date),
                                style: const TextStyle(fontSize: 12),
                              ),
                              title: Text(
                                tx.descriptionRaw,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: Text(
                                "${tx.amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isNegative
                                      ? Colors.green
                                      : Colors.black, // Credits are green
                                ),
                              ),
                              subtitle: Text(
                                "Norm: ${tx.merchantNorm}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _printToConsole,
        child: const Icon(Icons.print),
      ),
    );
  }
}
