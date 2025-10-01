import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/financial_goal.dart';
import '../models/recurring_transaction.dart';

class ExportService {
  // Export transactions to CSV
  Future<String> exportTransactionsToCSV(
      List<Transaction> transactions, {
        DateTime? startDate,
        DateTime? endDate,
      }) async {
    var filteredTransactions = transactions;

    if (startDate != null || endDate != null) {
      filteredTransactions = transactions.where((t) {
        final date = DateTime.parse(t.date);
        if (startDate != null && date.isBefore(startDate)) return false;
        if (endDate != null && date.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    final buffer = StringBuffer();

    // Headers
    buffer.writeln('Date,Merchant,Category,Amount,Type,Account');

    // Rows
    for (var transaction in filteredTransactions) {
      buffer.writeln(
          '${transaction.date},'
              '"${transaction.merchantName}",'
              '"${transaction.displayCategory}",'
              '${transaction.amount.abs()},'
              '${transaction.isExpense ? "Expense" : "Income"},'
              '"${transaction.accountName}"'
      );
    }

    return buffer.toString();
  }

  // Export monthly report
  Future<String> exportMonthlyReport({
    required List<Transaction> transactions,
    required List<BudgetStatus> budgetStatuses,
    required List<FinancialGoal> goals,
    required List<RecurringTransaction> recurring,
    required int year,
    required int month,
  }) async {
    final buffer = StringBuffer();
    final monthName = _getMonthName(month);

    buffer.writeln('BUDGETLY MONTHLY REPORT');
    buffer.writeln('$monthName $year');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('=' * 50);
    buffer.writeln('');

    // Summary
    final monthTransactions = transactions.where((t) {
      final date = DateTime.parse(t.date);
      return date.year == year && date.month == month;
    }).toList();

    final totalIncome = monthTransactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount.abs());

    final totalExpenses = monthTransactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .fold(0.0, (sum, t) => sum + t.amount);

    buffer.writeln('SUMMARY');
    buffer.writeln('-------');
    buffer.writeln('Total Income: \$${totalIncome.toStringAsFixed(2)}');
    buffer.writeln('Total Expenses: \$${totalExpenses.toStringAsFixed(2)}');
    buffer.writeln('Net: \$${(totalIncome - totalExpenses).toStringAsFixed(2)}');
    buffer.writeln('Transaction Count: ${monthTransactions.length}');
    buffer.writeln('');

    // Spending by category
    final categorySpending = <CategoryGroup, double>{};
    for (var t in monthTransactions) {
      if (t.isExpense && t.spendingCategory != SpendingCategory.transfer) {
        final group = t.spendingCategory.group;
        categorySpending[group] = (categorySpending[group] ?? 0) + t.amount;
      }
    }

    buffer.writeln('SPENDING BY CATEGORY');
    buffer.writeln('-------------------');
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedCategories) {
      final percent = (entry.value / totalExpenses * 100);
      buffer.writeln('${entry.key.displayName}: \$${entry.value.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)');
    }
    buffer.writeln('');

    // Budget performance
    if (budgetStatuses.isNotEmpty) {
      buffer.writeln('BUDGET PERFORMANCE');
      buffer.writeln('-----------------');
      for (var status in budgetStatuses) {
        buffer.writeln('${status.budget.category.displayName}:');
        buffer.writeln('  Budget: \$${status.budget.monthlyLimit.toStringAsFixed(2)}');
        buffer.writeln('  Spent: \$${status.spent.toStringAsFixed(2)}');
        buffer.writeln('  Remaining: \$${status.remaining.toStringAsFixed(2)}');
        buffer.writeln('  Status: ${status.isOverBudget ? "OVER BUDGET" : "${status.percentUsed.toStringAsFixed(0)}% used"}');
        buffer.writeln('');
      }
    }

    // Recurring charges
    if (recurring.isNotEmpty) {
      buffer.writeln('RECURRING CHARGES');
      buffer.writeln('----------------');
      final totalRecurring = recurring.fold(0.0, (sum, r) => sum + r.monthlyCost);
      buffer.writeln('Total Monthly Recurring: \$${totalRecurring.toStringAsFixed(2)}');
      buffer.writeln('');
      for (var r in recurring) {
        buffer.writeln('${r.merchantName}: \$${r.averageAmount.toStringAsFixed(2)} (${r.frequency.displayName})');
      }
      buffer.writeln('');
    }

    // Goals
    if (goals.isNotEmpty) {
      buffer.writeln('FINANCIAL GOALS');
      buffer.writeln('--------------');
      for (var goal in goals) {
        buffer.writeln('${goal.name}:');
        buffer.writeln('  Progress: \$${goal.currentAmount.toStringAsFixed(2)} / \$${goal.targetAmount.toStringAsFixed(2)} (${goal.progressPercentage.toStringAsFixed(0)}%)');
        buffer.writeln('  Target Date: ${goal.targetDate.toIso8601String().split('T')[0]}');
        if (!goal.isComplete) {
          buffer.writeln('  Days Remaining: ${goal.daysRemaining}');
          buffer.writeln('  Required Monthly: \$${goal.requiredMonthlySavings.toStringAsFixed(2)}');
        } else {
          buffer.writeln('  Status: COMPLETED');
        }
        buffer.writeln('');
      }
    }

    return buffer.toString();
  }

  // Save and share file
  Future<void> shareCSV(String csvContent, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }

  Future<void> shareReport(String reportContent, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(reportContent);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
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