// budgetly/lib/screens/recurring_screen.dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';

class RecurringScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const RecurringScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final recurring = RecurringTransactionDetector.detectRecurring(transactions);
    final subscriptions = recurring.where((r) => r.isSubscription).toList();
    final other = recurring.where((r) => !r.isSubscription).toList();

    final totalMonthlySubscriptions = subscriptions.fold(
      0.0,
          (sum, r) => sum + r.monthlyCost,
    );

    final totalMonthlyRecurring = recurring.fold(
      0.0,
          (sum, r) => sum + r.monthlyCost,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring & Subscriptions'),
      ),
      body: recurring.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No recurring transactions detected'),
            SizedBox(height: 8),
            Text(
              'Need at least 3 occurrences to detect patterns',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Monthly Subscriptions',
                  totalMonthlySubscriptions,
                  Colors.purple,
                  Icons.subscriptions,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Recurring',
                  totalMonthlyRecurring,
                  Colors.blue,
                  Icons.repeat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Subscriptions Section
          if (subscriptions.isNotEmpty) ...[
            const Text(
              'Subscriptions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...subscriptions.map((r) => _buildRecurringCard(r, context)),
            const SizedBox(height: 24),
          ],

          // Other Recurring Section
          if (other.isNotEmpty) ...[
            const Text(
              'Other Recurring',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...other.map((r) => _buildRecurringCard(r, context)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Card(
      color: color.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'per month',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransaction recurring, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: recurring.category.group.color.withValues(alpha:0.2),
          child: Icon(
            recurring.isSubscription ? Icons.subscriptions : Icons.repeat,
            color: recurring.category.group.color,
            size: 20,
          ),
        ),
        title: Text(
          recurring.merchantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recurring.description),
            Text(
              recurring.category.displayName,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${recurring.averageAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '\$${recurring.monthlyCost.toStringAsFixed(2)}/mo',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Occurrences', '${recurring.occurrenceCount}'),
                _buildDetailRow(
                  'Average Amount',
                  '\$${recurring.averageAmount.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  'Monthly Cost',
                  '\$${recurring.monthlyCost.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  'Annual Cost',
                  '\$${recurring.annualCost.toStringAsFixed(2)}',
                ),
                _buildDetailRow('Frequency', recurring.frequency.displayName),
                _buildDetailRow(
                  'First Seen',
                  '${recurring.firstOccurrence.month}/${recurring.firstOccurrence.day}/${recurring.firstOccurrence.year}',
                ),
                _buildDetailRow(
                  'Last Seen',
                  '${recurring.lastOccurrence.month}/${recurring.lastOccurrence.day}/${recurring.lastOccurrence.year}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recent Transactions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...recurring.transactions.take(5).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '\$${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}