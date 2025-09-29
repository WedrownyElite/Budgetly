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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: 'Refresh transactions',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: transactions.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading transactions...'),
                SizedBox(height: 8),
                Text(
                  'This may take a few seconds in test mode',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Text(
                      transaction.merchantName.isNotEmpty
                          ? transaction.merchantName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    transaction.merchantName.isNotEmpty
                        ? transaction.merchantName
                        : transaction.accountName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.displayCategory),
                      Text(
                        transaction.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '\$${transaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: transaction.isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}