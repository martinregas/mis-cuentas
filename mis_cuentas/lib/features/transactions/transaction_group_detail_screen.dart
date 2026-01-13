import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import 'transaction_list_screen.dart'; // Reuse TransactionTile

class TransactionGroupDetailScreen extends StatelessWidget {
  final String merchantName;
  final List<Transaction> transactions;
  final double totalAmount;

  const TransactionGroupDetailScreen({
    Key? key,
    required this.merchantName,
    required this.transactions,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(merchantName),
            Text(
              "${transactions.length} items", 
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Spent",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "ARS ${totalAmount.toStringAsFixed(2)}", // Assuming ARS for total for now, mixed currency handling is complex
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                // Custom tile for detail view: Show raw description to see specific merchant
                return ListTile(
                  title: Text(tx.descriptionRaw, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(tx.date)),
                  trailing: Text(
                    "${tx.currency} ${tx.amount.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
