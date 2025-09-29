// budgetly/lib/widgets/spending_chart_widget.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';

class SpendingChartWidget extends StatelessWidget {
  final List<Transaction> transactions;

  const SpendingChartWidget({super.key, required this.transactions});

  Map<CategoryGroup, double> _calculateSpendingByCategory() {
    final Map<CategoryGroup, double> spending = {};

    for (var transaction in transactions) {
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

  Map<String, double> _getMonthlySpending() {
    final Map<String, double> monthlySpending = {};

    for (var transaction in transactions) {
      if (transaction.spendingCategory == SpendingCategory.transfer) continue;
      if (!transaction.isExpense) continue;

      final date = DateTime.parse(transaction.date);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + transaction.amount;
    }

    return monthlySpending;
  }

  Map<String, Map<CategoryGroup, double>> _getCategorySpendingByMonth() {
    final Map<String, Map<CategoryGroup, double>> data = {};

    for (var transaction in transactions) {
      if (transaction.spendingCategory == SpendingCategory.transfer) continue;
      if (!transaction.isExpense) continue;

      final date = DateTime.parse(transaction.date);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final group = transaction.spendingCategory.group;

      data[monthKey] = data[monthKey] ?? {};
      data[monthKey]![group] = (data[monthKey]![group] ?? 0) + transaction.amount;
    }

    return data;
  }

  String _formatMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    final month = int.parse(parts[1]);
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
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
    final monthlySpending = _getMonthlySpending();
    final categoryByMonth = _getCategorySpendingByMonth();

    if (transactions.isEmpty) {
      return const Center(child: Text('No transaction data available'));
    }

    final sortedMonths = monthlySpending.keys.toList()..sort();
    final recentMonths = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;

    String currentMonth = sortedMonths.isNotEmpty ? sortedMonths.last : '';
    String previousMonth = sortedMonths.length > 1 ? sortedMonths[sortedMonths.length - 2] : '';

    double currentSpending = monthlySpending[currentMonth] ?? 0;
    double previousSpending = monthlySpending[previousMonth] ?? 0;
    double changePercent = previousSpending != 0
        ? ((currentSpending - previousSpending) / previousSpending * 100)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

        // Month-over-Month Comparison
        if (sortedMonths.length > 1) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Month Comparison',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMonthSummary(
                        _formatMonthKey(previousMonth),
                        previousSpending,
                        false,
                      ),
                      Icon(
                        changePercent > 0 ? Icons.trending_up : Icons.trending_down,
                        color: changePercent > 0 ? Colors.red : Colors.green,
                        size: 32,
                      ),
                      _buildMonthSummary(
                        _formatMonthKey(currentMonth),
                        currentSpending,
                        true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: changePercent > 0
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}% vs last month',
                        style: TextStyle(
                          color: changePercent > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Spending Trend Chart
        if (recentMonths.length > 1) ...[
          const Text(
            'Spending Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < recentMonths.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatMonthKey(recentMonths[index]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: recentMonths.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          monthlySpending[entry.value] ?? 0,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

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

        const SizedBox(height: 24),

        // Top Categories This Month
        if (categoryByMonth.containsKey(currentMonth)) ...[
          const Text(
            'Top Spending Categories This Month',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...(() {
            final categories = categoryByMonth[currentMonth]!.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return categories.take(5).map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry.key.color.withOpacity(0.2),
                  child: Icon(
                    Icons.category,
                    color: entry.key.color,
                    size: 20,
                  ),
                ),
                title: Text(entry.key.displayName),
                trailing: Text(
                  '\$${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ));
          })(),
        ],
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

  Widget _buildMonthSummary(String month, double amount, bool isCurrent) {
    return Column(
      children: [
        Text(
          month,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCurrent ? Colors.blue : Colors.grey[700],
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