import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionListWidget extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onRefresh;

  const TransactionListWidget({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  Color _getCategoryColor(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.transportation:
        return const Color(0xFF3B82F6);
      case CategoryGroup.dining:
        return const Color(0xFFEF4444);
      case CategoryGroup.groceries:
        return const Color(0xFF10B981);
      case CategoryGroup.bills:
        return const Color(0xFFF59E0B);
      case CategoryGroup.shopping:
        return const Color(0xFFEC4899);
      case CategoryGroup.entertainment:
        return const Color(0xFF8B5CF6);
      case CategoryGroup.healthcare:
        return const Color(0xFF14B8A6);
      case CategoryGroup.travel:
        return const Color(0xFF6366F1);
      case CategoryGroup.other:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIcon(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.transportation:
        return Icons.directions_car_rounded;
      case CategoryGroup.dining:
        return Icons.restaurant_rounded;
      case CategoryGroup.groceries:
        return Icons.shopping_cart_rounded;
      case CategoryGroup.bills:
        return Icons.receipt_long_rounded;
      case CategoryGroup.shopping:
        return Icons.shopping_bag_rounded;
      case CategoryGroup.entertainment:
        return Icons.movie_rounded;
      case CategoryGroup.healthcare:
        return Icons.favorite_rounded;
      case CategoryGroup.travel:
        return Icons.flight_rounded;
      case CategoryGroup.other:
        return Icons.more_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262D3D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? Center(
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
                const Text(
                  'Loading transactions...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: const Color(0xFF6366F1),
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final categoryColor = _getCategoryColor(
                transaction.spendingCategory.group,
              );
              final categoryIcon = _getCategoryIcon(
                transaction.spendingCategory.group,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF262D3D),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Could add transaction details modal here
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              categoryIcon,
                              color: categoryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.merchantName.isNotEmpty
                                      ? transaction.merchantName
                                      : transaction.accountName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  transaction.displayCategory,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: categoryColor.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  transaction.date,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
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
                                  '${transaction.isExpense ? '-' : '+'}\${transaction.amount.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: transaction.isExpense
                                        ? const Color(0xFFE53E3E)
                                        : const Color(0xFF48BB78),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}