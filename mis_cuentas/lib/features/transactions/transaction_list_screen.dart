
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/models/transaction.dart';
import '../../core/models/case.dart';
import '../cases/case_detail_screen.dart';
import 'transaction_group_detail_screen.dart';

// Providers
final allTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
   final db = ref.read(databaseHelperProvider);
   return db.getTransactions();
});

final allCasesProvider = FutureProvider<List<Case>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  return db.getCases();
});

final allPeriodsProvider = FutureProvider<List<String?>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  return db.getPeriods();
});

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGrouped = false;
  String? _selectedPeriod; // If null, show Period List

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    bool showingPeriods = _selectedPeriod == null && _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(showingPeriods ? "Resúmenes" : (_selectedPeriod ?? "Transactions")),
        leading: _selectedPeriod != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedPeriod = null),
            ) 
          : null,
        actions: [
          // Toggle Button (Only specific period view)
          if (_selectedPeriod != null)
            IconButton(
              icon: Icon(_isGrouped ? Icons.list : Icons.toc),
              tooltip: _isGrouped ? "Show List" : "Group by Merchant",
              onPressed: () {
                setState(() {
                  _isGrouped = !_isGrouped;
                });
              },
            ),
        ],
        bottom: _selectedPeriod == null ? TabBar(
          controller: _tabController,
          onTap: (index) {
             setState(() {}); 
          },
          tabs: const [
             Tab(text: "All"),
             Tab(text: "Suspicious"),
          ],
        ) : null, // Hide tabs when drilled down
      ),
      body: _selectedPeriod != null 
        ? _AllTransactionsTab(isGrouped: _isGrouped, periodFilter: _selectedPeriod)
        : TabBarView(
          controller: _tabController,
          children: [
            _PeriodsListTab(onPeriodSelected: (p) => setState(() => _selectedPeriod = p)),
            _SuspiciousTransactionsTab(),
          ],
        ),
    );
  }
}

class _PeriodsListTab extends ConsumerWidget {
  final Function(String) onPeriodSelected;
  const _PeriodsListTab({required this.onPeriodSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(allPeriodsProvider);
    final txsAsync = ref.watch(allTransactionsProvider); // To calculate totals

    return periodsAsync.when(
      data: (periods) {
        if (periods.isEmpty) {
          return const Center(
            child: Text("No hay resúmenes importados.\nImporta un PDF para comenzar.", textAlign: TextAlign.center)
          );
        }
        
        return txsAsync.when(
          data: (allTxs) {
            return ListView.builder(
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final String? period = periods[index]; // "2025-10" or null
                
                // Calculate Total for this period
                final txsInPeriod = allTxs.where((t) => t.period == period).toList();
                final total = txsInPeriod.fold(0.0, (sum, t) => sum + t.amount);
                final currency = txsInPeriod.isNotEmpty ? txsInPeriod.first.currency : "ARS";
                
                String displayDate = "SIN PERIODO";
                if (period != null) {
                   final parts = period.split('-');
                   final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                   displayDate = DateFormat('MMMM yyyy').format(date).toUpperCase();
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.purple),
                    title: Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${txsInPeriod.length} transacciones"),
                    trailing: Text(
                      "$currency ${total.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    onTap: () => onPeriodSelected(period ?? "NULL"), // Use dummy string for null nav
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_,__) => const SizedBox(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }
}

class _AllTransactionsTab extends ConsumerWidget {
  final bool isGrouped;
  final String? periodFilter;
  
  const _AllTransactionsTab({required this.isGrouped, this.periodFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(allTransactionsProvider);
    
    return txsAsync.when(
      data: (txs) {
        // Filter by Period
        List<Transaction> filteredTxs = txs;
        
        if (periodFilter == "NULL") {
          // Show items with NO period
          filteredTxs = txs.where((t) => t.period == null).toList();
        } else if (periodFilter != null) {
          // Show items for specific period
          filteredTxs = txs.where((t) => t.period == periodFilter).toList();
        }
        // If periodFilter is null (shouldn't happen in this view mode), show all or handle appropriately

        if (filteredTxs.isEmpty) return const Center(child: Text("No transactions found in this period."));
        
        if (isGrouped) {
          return _buildGroupedList(context, filteredTxs);
        } else {
          return ListView.builder(
            itemCount: filteredTxs.length,
            itemBuilder: (context, index) {
              final tx = filteredTxs[index];
              return TransactionTile(transaction: tx);
            },
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildGroupedList(BuildContext context, List<Transaction> txs) {
    // 1. Group by Merchant
    Map<String, List<Transaction>> groups = {};
    for (var tx in txs) {
      if (!groups.containsKey(tx.merchantNorm)) {
        groups[tx.merchantNorm] = [];
      }
      groups[tx.merchantNorm]!.add(tx);
    }
    
    // 2. Create list of map entries and sort by Total Amount (Desc)
    var sortedEntries = groups.entries.toList()
      ..sort((a, b) {
         double totalA = a.value.fold(0, (sum, t) => sum + t.amount);
         double totalB = b.value.fold(0, (sum, t) => sum + t.amount);
         return totalB.compareTo(totalA); // Descending
      });

    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final merchant = entry.key;
        final transactions = entry.value;
        final count = transactions.length;
        final totalFn = transactions.fold(0.0, (sum, t) => sum + t.amount);
        // Currency assumption: ARS for simplicity or take first.
        final currency = transactions.isNotEmpty ? transactions.first.currency : "ARS";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(merchant, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$count transactions"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$currency ${totalFn.toStringAsFixed(2)}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TransactionGroupDetailScreen(
                  merchantName: merchant,
                  transactions: transactions,
                  totalAmount: totalFn,
                )
              ));
            },
          ),
        );
      },
    );
  }
}

class _SuspiciousTransactionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need transactions that have cases.
    final casesAsync = ref.watch(allCasesProvider);
    final txsAsync = ref.watch(allTransactionsProvider);

    return casesAsync.when(
      data: (cases) {
         if (cases.isEmpty) return const Center(child: Text("No suspicious cases found."));
         
         return txsAsync.when(
            data: (txs) {
                 return ListView.builder(
                   itemCount: cases.length,
                   itemBuilder: (context, index) {
                     final caseItem = cases[index];
                     final tx = txs.firstWhere((t) => t.id == caseItem.transactionId, orElse: () => Transaction(date: DateTime.now(), descriptionRaw: "Unknown", merchantNorm: "Unknown", amount: 0, currency: "?", pdfName: ""));
                     
                     return InkWell(
                       onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseItem: caseItem, transaction: tx)));
                       },
                       child: Card(
                         color: Colors.redAccent.withOpacity(0.1),
                         margin: const EdgeInsets.all(8),
                         child: ListTile(
                           leading: Icon(Icons.warning, color: Colors.orange),
                           title: Text(tx.merchantNorm),
                           subtitle: Text("${caseItem.type.name.toUpperCase()}: ${caseItem.explanation}"),
                           trailing: Text("${tx.currency} ${tx.amount.toStringAsFixed(2)}"),
                         ),
                       ),
                     );
                   },
                 );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
         );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const TransactionTile({Key? key, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(transaction.merchantNorm, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(DateFormat('dd/MM/yyyy').format(transaction.date)),
      trailing: Text(
        "${transaction.currency} ${transaction.amount.toStringAsFixed(2)}",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
