// budgetly/lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';

enum DateRangeFilter {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  custom;

  String get displayName {
    switch (this) {
      case DateRangeFilter.thisWeek:
        return 'This Week';
      case DateRangeFilter.lastWeek:
        return 'Last Week';
      case DateRangeFilter.thisMonth:
        return 'This Month';
      case DateRangeFilter.lastMonth:
        return 'Last Month';
      case DateRangeFilter.last3Months:
        return 'Last 3 Months';
      case DateRangeFilter.custom:
        return 'Custom Range';
    }
  }
}

class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const AnalyticsScreen({super.key, required this.transactions});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateRangeFilter _selectedRange = DateRangeFilter.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  List<Transaction> get _filteredTransactions {
    if (_selectedRange == DateRangeFilter.custom &&
        (_customStartDate == null || _customEndDate == null)) {
      return widget.transactions;
    }

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (_selectedRange) {
      case DateRangeFilter.thisWeek:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case DateRangeFilter.lastWeek:
        final lastWeekEnd = now.subtract(Duration(days: now.weekday));
        endDate = lastWeekEnd;
        startDate = lastWeekEnd.subtract(const Duration(days: 6));
        break;
      case DateRangeFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DateRangeFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(now.year, now.month, 0);
        break;
      case DateRangeFilter.last3Months:
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case DateRangeFilter.custom:
        startDate = _customStartDate!;
        endDate = _customEndDate!;
        break;
    }

    return widget.transactions.where((t) {
      final date = DateTime.parse(t.date);
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // Calculate spending by category
  Map<CategoryGroup, double> _getSpendingByCategory() {
    final Map<CategoryGroup, double> spending = {};
    for (var t in _filteredTransactions) {
      if (t.isExpense && t.spendingCategory != SpendingCategory.transfer) {
        final group = t.spendingCategory.group;
        spending[group] = (spending[group] ?? 0) + t.amount;
      }
    }
    return spending;
  }

  // Calculate daily spending trend
  Map<DateTime, double> _getDailySpending() {
    final Map<DateTime, double> daily = {};
    for (var t in _filteredTransactions) {
      if (t.isExpense && t.spendingCategory != SpendingCategory.transfer) {
        final date = DateTime.parse(t.date);
        final dayKey = DateTime(date.year, date.month, date.day);
        daily[dayKey] = (daily[dayKey] ?? 0) + t.amount;
      }
    }
    return daily;
  }

  // Get top merchants
  List<MapEntry<String, double>> _getTopMerchants({int limit = 5}) {
    final Map<String, double> merchants = {};
    for (var t in _filteredTransactions) {
      if (t.isExpense && t.spendingCategory != SpendingCategory.transfer) {
        merchants[t.merchantName] = (merchants[t.merchantName] ?? 0) + t.amount;
      }
    }
    final sorted = merchants.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  // Calculate averages
  double _getAverageDaily() {
    final spending = _getDailySpending();
    if (spending.isEmpty) return 0;
    final total = spending.values.fold(0.0, (sum, v) => sum + v);
    return total / spending.length;
  }

  double _getAverageTransaction() {
    final expenses = _filteredTransactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .toList();
    if (expenses.isEmpty) return 0;
    final total = expenses.fold(0.0, (sum, t) => sum + t.amount);
    return total / expenses.length;
  }

  void _showDateRangePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
        context: context,
        builder: (context) => SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'Select Date Range',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...DateRangeFilter.values.map((filter) {
                final isSelected = _selectedRange == filter;
  
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                        : const Color(0xFF6366F1).withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      filter.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF6366F1) : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF6366F1))
                        : null,
                    onTap: () async {
                      if (filter == DateRangeFilter.custom) {
                        Navigator.pop(context);
                        await _showCustomDatePicker();
                      } else {
                        setState(() => _selectedRange = filter);
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }),
              ],
            ),
          ),
        ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (range != null) {
      setState(() {
        _selectedRange = DateRangeFilter.custom;
        _customStartDate = range.start;
        _customEndDate = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spending = _getSpendingByCategory();
    final totalExpenses = spending.values.fold(0.0, (sum, v) => sum + v);
    final totalIncome = _filteredTransactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
    final topMerchants = _getTopMerchants();
    final avgDaily = _getAverageDaily();
    final avgTransaction = _getAverageTransaction();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                _selectedRange == DateRangeFilter.custom && _customStartDate != null
                    ? '${_customStartDate!.month}/${_customStartDate!.day} - ${_customEndDate!.month}/${_customEndDate!.day}'
                    : _selectedRange.displayName,
                style: const TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      body: _filteredTransactions.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No transaction data for this period'),
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
                  'Total Income',
                  totalIncome,
                  Icons.arrow_downward,
                  Colors.green,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Expenses',
                  totalExpenses,
                  Icons.arrow_upward,
                  Colors.red,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Net',
                  totalIncome - totalExpenses,
                  Icons.account_balance_wallet,
                  totalIncome > totalExpenses ? Colors.green : Colors.red,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Savings Rate',
                  totalIncome > 0
                      ? ((totalIncome - totalExpenses) / totalIncome * 100)
                      : 0,
                  Icons.savings,
                  totalIncome > totalExpenses ? Colors.green : Colors.red,
                  isDark,
                  isPercentage: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Spending Trend Chart
          _buildSectionHeader('Daily Spending Trend', isDark),
          const SizedBox(height: 12),
          _buildSpendingTrendChart(isDark),
          const SizedBox(height: 24),

          // Category Breakdown
          _buildSectionHeader('Spending by Category', isDark),
          const SizedBox(height: 12),
          _buildCategoryPieChart(spending, totalExpenses, isDark),
          const SizedBox(height: 24),

          // Category List
          _buildCategoryList(spending, totalExpenses, isDark),
          const SizedBox(height: 24),

          // Averages
          _buildSectionHeader('Averages', isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Avg Daily',
                  avgDaily,
                  Icons.calendar_today,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Avg Transaction',
                  avgTransaction,
                  Icons.receipt,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Merchants
          _buildSectionHeader('Top Merchants', isDark),
          const SizedBox(height: 12),
          _buildTopMerchantsList(topMerchants, totalExpenses, isDark),
          const SizedBox(height: 24),

          // Transaction Summary
          _buildSectionHeader('Transaction Summary', isDark),
          const SizedBox(height: 12),
          _buildTransactionSummary(isDark),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSummaryCard(
      String label,
      double value,
      IconData icon,
      Color color,
      bool isDark, {
        bool isPercentage = false,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isPercentage
                    ? '${value.toStringAsFixed(1)}%'
                    : '\$${value.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, double value, IconData icon, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '\$${value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingTrendChart(bool isDark) {
    final daily = _getDailySpending();
    if (daily.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No spending data')),
        ),
      );
    }

    final sortedDates = daily.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), daily[entry.value]!);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
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
                        '\$${(value / 100).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (sortedDates.length / 5).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedDates.length) {
                        final date = sortedDates[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF6366F1),
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(
      Map<CategoryGroup, double> spending,
      double total,
      bool isDark,
      ) {
    if (spending.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No category data')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: spending.entries.map((entry) {
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
                  color: entry.key.color,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
      Map<CategoryGroup, double> spending,
      double total,
      bool isDark,
      ) {
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Column(
        children: sorted.map((entry) {
          final percentage = (entry.value / total * 100);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.key.color.withValues(alpha: 0.2),
              child: Icon(Icons.category, color: entry.key.color, size: 20),
            ),
            title: Text(entry.key.displayName),
            subtitle: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(entry.key.color),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${entry.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopMerchantsList(
      List<MapEntry<String, double>> merchants,
      double total,
      bool isDark,
      ) {
    if (merchants.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No merchant data')),
        ),
      );
    }

    return Card(
      child: Column(
        children: merchants.asMap().entries.map((entry) {
          final index = entry.key;
          final merchant = entry.value;
          final percentage = (merchant.value / total * 100);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            title: Text(merchant.key),
            subtitle: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${merchant.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionSummary(bool isDark) {
    final expenses = _filteredTransactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .toList();
    final income = _filteredTransactions.where((t) => t.isIncome).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Total Transactions', '${_filteredTransactions.length}', isDark),
            const Divider(),
            _buildSummaryRow('Expense Count', '${expenses.length}', isDark),
            const Divider(),
            _buildSummaryRow('Income Count', '${income.length}', isDark),
            const Divider(),
            _buildSummaryRow(
              'Largest Expense',
              expenses.isNotEmpty
                  ? '\$${expenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'
                  : '\$0.00',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}