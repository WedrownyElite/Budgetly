import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';

class SpendingChartWidget extends StatelessWidget {
  final List<Transaction> transactions;

  const SpendingChartWidget({super.key, required this.transactions});

  Map<CategoryGroup, double> _calculateSpendingByCategory() {
    final Map<CategoryGroup, double> spending = {};

    for (var transaction in transactions) {
      // Skip transfers - they're not real expenses
      if (transaction.spendingCategory == SpendingCategory.transfer) {
        continue;
      }

      if (transaction.isExpense) {
        final group = transaction.spendingCategory.group;
        spending[group] = (spending[group] ?? 0) + transaction.amount;
      }
    }

    return spending;
  }

  double _calculateTotalExpenses() {
    return transactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double _calculateTotalIncome() {
    return transactions
        .where((t) => t.isIncome)
        .fold(0, (sum, t) => sum + t.amount.abs());
  }

  @override
  Widget build(BuildContext context) {
    final spendingByCategory = _calculateSpendingByCategory();
    final totalIncome = _calculateTotalIncome();
    final totalExpenses = _calculateTotalExpenses();

    if (transactions.isEmpty) {
      return const Center(child: Text('No transaction data available'));
    }

    return Column(
      children: [
        // Income vs Expenses Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Income', totalIncome, Colors.green),
                _buildSummaryItem('Expenses', totalExpenses, Colors.red),
                _buildSummaryItem('Net', totalIncome - totalExpenses,
                    totalIncome > totalExpenses ? Colors.green : Colors.red),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Pie Chart for Spending Categories
        const Text(
          'Spending by Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: _buildPieChartSections(spendingByCategory, totalExpenses),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: spendingByCategory.entries.map((entry) {
            return _buildLegendItem(
              entry.key.displayName,
              _getCategoryColor(entry.key),
              entry.value,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      Map<CategoryGroup, double> spending, double total) {
    return spending.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: _getCategoryColor(entry.key),
      );
    }).toList();
  }

  Widget _buildLegendItem(String label, Color color, double amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: \$${amount.toStringAsFixed(2)}'),
      ],
    );
  }

  Color _getCategoryColor(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.transportation:
        return Colors.blue;
      case CategoryGroup.dining:
        return Colors.red;
      case CategoryGroup.groceries:
        return Colors.green;
      case CategoryGroup.bills:
        return Colors.orange;
      case CategoryGroup.shopping:
        return Colors.pink;
      case CategoryGroup.entertainment:
        return Colors.purple;
      case CategoryGroup.healthcare:
        return Colors.teal;
      case CategoryGroup.travel:
        return Colors.indigo;
      case CategoryGroup.other:
        return Colors.grey;
    }
  }
}