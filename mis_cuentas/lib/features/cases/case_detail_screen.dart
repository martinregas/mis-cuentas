
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/case.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import '../transactions/transaction_list_screen.dart'; // For refreshing providers

class CaseDetailScreen extends ConsumerWidget {
  final Case caseItem;
  final Transaction transaction;

  const CaseDetailScreen({Key? key, required this.caseItem, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Case Detail")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(context),
            const SizedBox(height: 24),
            Text("Actions", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, color: Colors.green),
                  label: const Text("Mark as Approved"),
                  onPressed: () => _updateStatus(context, ref, CaseStatus.approved),
                ),
                ActionChip(
                  avatar: const Icon(Icons.visibility_off_outlined, color: Colors.grey),
                  label: const Text("Ignore"),
                  onPressed: () => _updateStatus(context, ref, CaseStatus.ignored),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text("Claim Helper", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_generateClaimText(), style: const TextStyle(fontFamily: 'Courier', fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generateClaimText()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
                          }, 
                          icon: const Icon(Icons.copy), 
                          label: const Text("Copy")
                        ),
                        TextButton.icon(
                          onPressed: () {
                             Share.share(_generateClaimText(), subject: "Reclamo consumo ${transaction.merchantNorm}");
                          }, 
                          icon: const Icon(Icons.share), 
                          label: const Text("Share")
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(caseItem.type.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(caseItem.explanation, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              title: const Text("Transaction"),
              subtitle: Text(transaction.merchantNorm),
              trailing: Text("${transaction.currency} ${transaction.amount.toStringAsFixed(2)}"),
            ),
            ListTile(
              title: const Text("Date"),
              subtitle: Text(transaction.date.toIso8601String().split('T')[0]),
            ),
          ],
        ),
      ),
    );
  }

  String _generateClaimText() {
    return "Hola, quiero desconocer/reclamar el consumo de ${transaction.currency} ${transaction.amount.toStringAsFixed(2)} "
           "realizado el ${transaction.date.toIso8601String().split('T')[0]} en ${transaction.merchantNorm}. "
           "Motivo: ${caseItem.explanation}";
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, CaseStatus status) async {
    await ref.read(databaseHelperProvider).updateCaseStatus(caseItem.id!, status);
    ref.refresh(allCasesProvider); // Refresh the list
    if (context.mounted) {
        Navigator.pop(context);
    }
  }
}
