import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../services/export_service.dart';
import '../services/budget_storage_service.dart';
import '../services/accessibility_service.dart';

class ExportScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const ExportScreen({super.key, required this.transactions});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService();
  final BudgetStorageService _budgetService = BudgetStorageService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isExporting = false;

  Future<void> _exportTransactions(bool asPDF) async {
    setState(() => _isExporting = true);

    try {
      if (asPDF) {
        await _exportService.exportTransactionsToPDF(
          widget.transactions,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        final csv = await _exportService.exportTransactionsToCSV(
          widget.transactions,
          startDate: _startDate,
          endDate: _endDate,
        );
        final filename = 'budgetly_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
        await _exportService.shareCSV(csv, filename);
      }

      if (mounted) {
        AccessibilityService.announce(context, 'Transactions exported successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportMonthlyReport() async {
    final now = DateTime.now();

    setState(() => _isExporting = true);

    try {
      // Load all data
      final budgets = await _budgetService.getBudgets();
      final goals = await _budgetService.getGoals();
      final recurring = RecurringTransactionDetector.detectRecurring(widget.transactions);

      // Calculate budget statuses
      final Map<CategoryGroup, double> spending = {};
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var transaction in widget.transactions) {
        if (transaction.spendingCategory == SpendingCategory.transfer) continue;
        if (!transaction.isExpense) continue;

        final transactionDate = DateTime.parse(transaction.date);
        if (transactionDate.isBefore(firstDayOfMonth)) continue;

        final group = transaction.spendingCategory.group;
        spending[group] = (spending[group] ?? 0) + transaction.amount;
      }

      final budgetStatuses = budgets.map((budget) {
        final spent = spending[budget.category] ?? 0;
        return BudgetStatus(budget: budget, spent: spent);
      }).toList();

      await _exportService.exportMonthlyReportPDF(
        transactions: widget.transactions,
        budgetStatuses: budgetStatuses,
        goals: goals,
        recurring: recurring,
        year: now.year,
        month: now.month,
      );

      if (mounted) {
        AccessibilityService.announce(context, 'Monthly report exported successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly report exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export Transactions Section
          const Text(
            'Export Transactions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Export your transactions to CSV format',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Date Range Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start Date', style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                            _startDate != null
                                ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                                : 'Not set',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('End Date', style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                            _endDate != null
                                ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                                : 'Not set',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear dates'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportTransactions(false),
            icon: _isExporting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.description),
            label: Text(_isExporting ? 'Exporting...' : 'Export as CSV'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportTransactions(true),
            icon: _isExporting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_isExporting ? 'Exporting...' : 'Export as PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red.shade700,
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Export Reports Section
          const Text(
            'Export Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate comprehensive monthly reports',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              title: const Text('Current Month Report'),
              subtitle: Text(
                '${_getMonthName(now.month)} ${now.year}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isExporting ? null : _exportMonthlyReport,
            ),
          ),

          const SizedBox(height: 16),

          // Report includes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Includes:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildReportItem(Icons.attach_money, 'Income & Expense Summary', isDark),
                  _buildReportItem(Icons.pie_chart, 'Spending by Category', isDark),
                  _buildReportItem(Icons.account_balance_wallet, 'Budget Performance', isDark),
                  _buildReportItem(Icons.autorenew, 'Recurring Charges', isDark),
                  _buildReportItem(Icons.flag, 'Financial Goals Progress', isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}