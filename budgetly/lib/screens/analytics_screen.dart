// budgetly/lib/screens/analytics_screen.dart
// Alternative implementation without deprecated Radio widget
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../widgets/spending_chart_widget.dart';

enum DateRangeFilter {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  lastYear,
  allTime,
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
      case DateRangeFilter.thisYear:
        return 'This Year';
      case DateRangeFilter.lastYear:
        return 'Last Year';
      case DateRangeFilter.allTime:
        return 'All Time';
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
    if (_selectedRange == DateRangeFilter.allTime) {
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
      case DateRangeFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        break;
      case DateRangeFilter.lastYear:
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31);
        break;
      case DateRangeFilter.custom:
        if (_customStartDate == null || _customEndDate == null) {
          return widget.transactions;
        }
        startDate = _customStartDate!;
        endDate = _customEndDate!;
        break;
      case DateRangeFilter.allTime:
        return widget.transactions;
    }

    return widget.transactions.where((t) {
      final date = DateTime.parse(t.date);
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  void _showDateRangePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
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
                      ? (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.1))
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range),
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SpendingChartWidget(transactions: _filteredTransactions),
      ),
    );
  }
}