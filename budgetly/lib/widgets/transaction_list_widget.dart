// budgetly/lib/widgets/transaction_list_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/accessibility_service.dart';

class TransactionListWidget extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onRefresh;

  const TransactionListWidget({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  Color _getCategoryColor(CategoryGroup group, bool isDark) {
    if (isDark) {
      switch (group) {
        case CategoryGroup.transportation: return const Color(0xFF60A5FA);
        case CategoryGroup.dining: return const Color(0xFFF87171);
        case CategoryGroup.groceries: return const Color(0xFF34D399);
        case CategoryGroup.bills: return const Color(0xFFFBBF24);
        case CategoryGroup.shopping: return const Color(0xFFF472B6);
        case CategoryGroup.entertainment: return const Color(0xFFA78BFA);
        case CategoryGroup.healthcare: return const Color(0xFF2DD4BF);
        case CategoryGroup.travel: return const Color(0xFF818CF8);
        case CategoryGroup.other: return const Color(0xFF9CA3AF);
      }
    }

    switch (group) {
      case CategoryGroup.transportation: return const Color(0xFF3B82F6);
      case CategoryGroup.dining: return const Color(0xFFEF4444);
      case CategoryGroup.groceries: return const Color(0xFF10B981);
      case CategoryGroup.bills: return const Color(0xFFF59E0B);
      case CategoryGroup.shopping: return const Color(0xFFEC4899);
      case CategoryGroup.entertainment: return const Color(0xFF8B5CF6);
      case CategoryGroup.healthcare: return const Color(0xFF14B8A6);
      case CategoryGroup.travel: return const Color(0xFF6366F1);
      case CategoryGroup.other: return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIcon(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.transportation: return Icons.directions_car_rounded;
      case CategoryGroup.dining: return Icons.restaurant_rounded;
      case CategoryGroup.groceries: return Icons.shopping_cart_rounded;
      case CategoryGroup.bills: return Icons.receipt_long_rounded;
      case CategoryGroup.shopping: return Icons.shopping_bag_rounded;
      case CategoryGroup.entertainment: return Icons.movie_rounded;
      case CategoryGroup.healthcare: return Icons.favorite_rounded;
      case CategoryGroup.travel: return Icons.flight_rounded;
      case CategoryGroup.other: return Icons.more_horiz_rounded;
    }
  }

  Map<String, List<Transaction>> _groupTransactionsByDate() {
    final Map<String, List<Transaction>> grouped = {};
    for (var transaction in transactions) {
      final date = transaction.date;
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(transaction);
    }
    return grouped;
  }

  String _formatDateHeader(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final transactionDate = DateTime(date.year, date.month, date.day);

      if (transactionDate == today) {
        return 'Today';
      } else if (transactionDate == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE, MMM d, yyyy').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  double _getDailyTotal(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .fold(0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Refresh transactions',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? Semantics(
            liveRegion: true,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.2),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 48,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading transactions...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few seconds',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Loading transactions',
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: const Color(0xFF6366F1),
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : _buildGroupedTransactionsList(isDark),
        ),
      ],
    );
  }

  Widget _buildGroupedTransactionsList(bool isDark) {
    final groupedTransactions = _groupTransactionsByDate();
    final sortedDates = groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

    return Semantics(
      label: '${transactions.length} transactions',
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final dateTransactions = groupedTransactions[date]!;
          final dailyTotal = _getDailyTotal(dateTransactions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: '${AccessibilityService.formatDateForScreenReader(date)}, ${dateTransactions.length} transactions, total ${AccessibilityService.formatCurrencyForScreenReader(dailyTotal)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: ExcludeSemantics(
                          child: Text(
                            _formatDateHeader(date),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (dailyTotal > 0) ...[
                        const SizedBox(width: 8),
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-\$${dailyTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ...dateTransactions.map((transaction) {
                return _buildTransactionCard(transaction, isDark);
              }),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, bool isDark) {
    final categoryColor = _getCategoryColor(transaction.spendingCategory.group, isDark);
    final categoryIcon = _getCategoryIcon(transaction.spendingCategory.group);

    final semanticLabel = AccessibilityService.transactionSemanticLabel(
      merchantName: transaction.merchantName,
      category: transaction.displayCategory,
      amount: transaction.amount,
      isExpense: transaction.isExpense,
      date: transaction.date,
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F29) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Transaction details
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, color: categoryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            transaction.merchantName.isNotEmpty
                                ? transaction.merchantName
                                : transaction.accountName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.displayCategory,
                            style: TextStyle(
                              fontSize: 13,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: transaction.isExpense
                              ? const Color(0xFFE53E3E).withValues(alpha: 0.15)
                              : const Color(0xFF48BB78).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${transaction.isExpense ? '-' : '+'}\$${transaction.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: transaction.isExpense
                                ? const Color(0xFFE53E3E)
                                : const Color(0xFF48BB78),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}