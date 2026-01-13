
import '../../core/models/transaction.dart';
import '../../core/models/case.dart';

class AuditEngine {
  /// Analyzes new transactions against historical data to find anomalies.
  /// [newTransactions] are the ones just imported (and saved).
  /// [history] is the list of all transactions in the DB (including new ones).
  static List<Case> audit(List<Transaction> newTransactions, List<Transaction> history) {
    List<Case> anomalies = [];

    // Sort history by date desc for easier lookup
    history.sort((a, b) => b.date.compareTo(a.date));

    for (var tx in newTransactions) {
        if (tx.id == null) continue; // Should have ID after save
        
        // 1. Duplicates: same merchant + amount within 48h
        // We look for OTHER transactions with same merchant/amount
        // We need to avoid matching the transaction itself (check ID)
        bool isDuplicate = history.any((h) {
          if (h.id == tx.id) return false; // Skip self
          if (h.merchantNorm != tx.merchantNorm) return false;
          if ((h.amount - tx.amount).abs() > 0.01) return false;
          
          Duration diff = h.date.difference(tx.date).abs();
          return diff.inHours <= 48;
        });

        if (isDuplicate) {
          anomalies.add(Case(
            transactionId: tx.id!,
            type: CaseType.duplicate,
            explanation: "Duplicate transaction found for ${tx.merchantNorm} within 48h.",
          ));
        }

        // 2. High Amount: > 2.5 * avg of history for this merchant
        // Filter history for this merchant (excluding current tx)
        List<Transaction> merchantHistory = history.where((h) => 
          h.id != tx.id && h.merchantNorm == tx.merchantNorm
        ).toList();

        if (merchantHistory.length >= 3) {
          double avg = merchantHistory.map((e) => e.amount).reduce((a, b) => a + b) / merchantHistory.length;
          if (tx.amount > avg * 2.5) {
             anomalies.add(Case(
              transactionId: tx.id!,
              type: CaseType.highAmount,
              explanation: "Amount \$${tx.amount} is significantly higher than average \$${avg.toStringAsFixed(2)}.",
            ));
          }
        }

        // 3. Subscription suspected: 25-35 days interval
        // Check if there's a previous tx 25-35 days ago
        // This is a simple heuristic.
        bool isSubscription = merchantHistory.any((h) {
          int days = h.date.difference(tx.date).abs().inDays;
          return days >= 25 && days <= 35;
        });
        
        // Mark as subscription if we see a pattern. 
        // Note: Logic says "Suscripción sospechosa: repetición mensual ... y no marcada como approved".
        // "no marcada como approved" implies checking past Cases, but for MVP we check simplified rule.
        // We'll mark it as subscription if found.
        if (isSubscription) {
           anomalies.add(Case(
              transactionId: tx.id!,
              type: CaseType.subscription,
              explanation: "Recurring monthly payment detected (approx 30 days).",
            ));
        }
    }

    return anomalies;
  }
}
