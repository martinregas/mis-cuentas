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
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen>
    with SingleTickerProviderStateMixin {
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
        title: Text(
          showingPeriods ? "Resúmenes" : (_selectedPeriod ?? "Transactions"),
        ),
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
        bottom: _selectedPeriod == null
            ? TabBar(
                controller: _tabController,
                onTap: (index) {
                  setState(() {});
                },
                tabs: const [
                  Tab(text: "All"),
                  Tab(text: "Suspicious"),
                ],
              )
            : null, // Hide tabs when drilled down
      ),
      body: _selectedPeriod != null
          ? _AllTransactionsTab(
              isGrouped: _isGrouped,
              periodFilter: _selectedPeriod,
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _PeriodsListTab(
                  onPeriodSelected: (p) => setState(() => _selectedPeriod = p),
                ),
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
            child: Text(
              "No hay resúmenes importados.\nImporta un PDF para comenzar.",
              textAlign: TextAlign.center,
            ),
          );
        }

        return txsAsync.when(
          data: (allTxs) {
            return ListView.builder(
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final String? period = periods[index]; // "2025-10" or null

                // Calculate Totals Separately
                final txsInPeriod = allTxs
                    .where((t) => t.period == period)
                    .toList();
                double totalARS = 0;
                double totalUSD = 0;
                for (var t in txsInPeriod) {
                  if (t.currency == 'USD') {
                    totalUSD += t.amount;
                  } else {
                    totalARS += t.amount;
                  }
                }

                String displayDate = "SIN PERIODO";
                if (period != null) {
                  final parts = period.split('-');
                  final date = DateTime(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                  );
                  displayDate = DateFormat(
                    'MMMM yyyy',
                  ).format(date).toUpperCase();
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.purple,
                    ),
                    title: Text(
                      displayDate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("${txsInPeriod.length} transacciones"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (totalARS != 0 ||
                            totalUSD ==
                                0) // Always show ARS if both are 0, or if it has value
                          Text(
                            "ARS ${totalARS.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        if (totalUSD != 0)
                          Text(
                            "USD ${totalUSD.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => onPeriodSelected(period ?? "NULL"),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }
}

class _AllTransactionsTab extends ConsumerStatefulWidget {
  final bool isGrouped;
  final String? periodFilter;

  const _AllTransactionsTab({required this.isGrouped, this.periodFilter});

  @override
  ConsumerState<_AllTransactionsTab> createState() =>
      _AllTransactionsTabState();
}

class _AllTransactionsTabState extends ConsumerState<_AllTransactionsTab> {
  String _selectedCurrency = 'ARS';

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(allTransactionsProvider);

    return txsAsync.when(
      data: (txs) {
        // 1. Filter by Period (First)
        List<Transaction> periodTxs = txs;

        if (widget.periodFilter == "NULL") {
          // Show items with NO period
          periodTxs = txs.where((t) => t.period == null).toList();
        } else if (widget.periodFilter != null) {
          // Show items for specific period
          periodTxs = txs
              .where((t) => t.period == widget.periodFilter)
              .toList();
        }

        if (periodTxs.isEmpty) {
          return const Center(
            child: Text("No transactions found in this period."),
          );
        }

        // 2. Filter by Currency (Second)
        List<Transaction> displayTxs = periodTxs
            .where((t) => t.currency == _selectedCurrency)
            .toList();

        // Calculate Totals for Header
        double totalCurrency = displayTxs.fold(0.0, (sum, t) => sum + t.amount);

        return Column(
          children: [
            // Filter Header
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  // Currency Toggle
                  ToggleButtons(
                    constraints: const BoxConstraints(
                      minHeight: 32,
                      minWidth: 60,
                    ),
                    isSelected: [
                      _selectedCurrency == 'ARS',
                      _selectedCurrency == 'USD',
                    ],
                    borderRadius: BorderRadius.circular(8),
                    onPressed: (index) {
                      setState(() {
                        _selectedCurrency = index == 0 ? 'ARS' : 'USD';
                      });
                    },
                    children: const [
                      Text(
                        "ARS",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "USD",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Total Display for Selected Currency
                  Text(
                    "$_selectedCurrency ${totalCurrency.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _selectedCurrency == 'USD'
                          ? Colors.green
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // List Content
            Expanded(
              child: displayTxs.isEmpty
                  ? Center(child: Text("No $_selectedCurrency transactions."))
                  : widget.isGrouped
                  ? _buildGroupedList(context, displayTxs)
                  : ListView.builder(
                      itemCount: displayTxs.length,
                      itemBuilder: (context, index) {
                        final tx = displayTxs[index];
                        return TransactionTile(transaction: tx);
                      },
                    ),
            ),
          ],
        );
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
        // Currency is already filtered
        final currency = _selectedCurrency;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(
              merchant,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("$count transactions"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$currency ${totalFn.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionGroupDetailScreen(
                    merchantName: merchant,
                    transactions: transactions,
                    totalAmount: totalFn,
                  ),
                ),
              );
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
        if (cases.isEmpty)
          return const Center(child: Text("No suspicious cases found."));

        return txsAsync.when(
          data: (txs) {
            return ListView.builder(
              itemCount: cases.length,
              itemBuilder: (context, index) {
                final caseItem = cases[index];
                final tx = txs.firstWhere(
                  (t) => t.id == caseItem.transactionId,
                  orElse: () => Transaction(
                    date: DateTime.now(),
                    descriptionRaw: "Unknown",
                    merchantNorm: "Unknown",
                    amount: 0,
                    currency: "?",
                    pdfName: "",
                  ),
                );

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaseDetailScreen(
                          caseItem: caseItem,
                          transaction: tx,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.redAccent.withOpacity(0.1),
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(tx.merchantNorm),
                      subtitle: Text(
                        "${caseItem.type.name.toUpperCase()}: ${caseItem.explanation}",
                      ),
                      trailing: Text(
                        "${tx.currency} ${tx.amount.toStringAsFixed(2)}",
                      ),
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
  const TransactionTile({Key? key, required this.transaction})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        transaction.merchantNorm,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(DateFormat('dd/MM/yyyy').format(transaction.date)),
      trailing: Text(
        "${transaction.currency} ${transaction.amount.toStringAsFixed(2)}",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
