// budgetly/lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/financial_goal.dart';
import '../models/recurring_transaction.dart';

class ExportService {
  // Load logo from assets
  Future<Uint8List?> _loadLogo() async {
    try {
      final byteData = await rootBundle.load('assets/images/budgetly_logo.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

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

  // Export transactions to PDF
  Future<void> exportTransactionsToPDF(
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

    final pdf = pw.Document();
    final logo = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header with Logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Image(
                        pw.MemoryImage(logo),
                        width: 60,
                        height: 60,
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'BUDGETLY',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#6366F1'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Transaction Export',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    if (startDate != null || endDate != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Period: ${startDate != null ? _formatDate(startDate) : 'Beginning'} - ${endDate != null ? _formatDate(endDate) : 'Present'}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColor.fromHex('#6366F1'), thickness: 2),
            pw.SizedBox(height: 20),

            // Summary
            _buildPdfSummary(filteredTransactions),
            pw.SizedBox(height: 30),

            // Transactions Table
            pw.Text(
              'Transactions',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Merchant', 'Category', 'Amount', 'Type'],
              data: filteredTransactions.map((t) => [
                t.date,
                t.merchantName,
                t.displayCategory,
                '\$${t.amount.abs().toStringAsFixed(2)}',
                t.isExpense ? 'Expense' : 'Income',
              ]).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#6366F1'),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final filename = 'budgetly_transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
      ),
    );
  }

  // Export monthly report to PDF
  Future<void> exportMonthlyReportPDF({
    required List<Transaction> transactions,
    required List<BudgetStatus> budgetStatuses,
    required List<FinancialGoal> goals,
    required List<RecurringTransaction> recurring,
    required int year,
    required int month,
  }) async {
    final pdf = pw.Document();
    final logo = await _loadLogo();
    final monthName = _getMonthName(month);

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

    // Group expenses by category
    final Map<CategoryGroup, double> categorySpending = {};
    for (var transaction in monthTransactions) {
      if (transaction.isExpense && transaction.spendingCategory != SpendingCategory.transfer) {
        final group = transaction.spendingCategory.group;
        categorySpending[group] = (categorySpending[group] ?? 0) + transaction.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header with Logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Image(
                        pw.MemoryImage(logo),
                        width: 70,
                        height: 70,
                      ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'BUDGETLY',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#6366F1'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Monthly Financial Report',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '$monthName $year',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColor.fromHex('#6366F1'),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromHex('#6366F1'), thickness: 2),
            pw.SizedBox(height: 30),

            // Executive Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F5F7'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColor.fromHex('#6366F1'), width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EXECUTIVE SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#6366F1'),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Income', totalIncome, PdfColors.green700),
                      pw.Container(width: 1, height: 60, color: PdfColors.grey400),
                      _buildSummaryItem('Total Expenses', totalExpenses, PdfColors.red700),
                      pw.Container(width: 1, height: 60, color: PdfColors.grey400),
                      _buildSummaryItem(
                        'Net',
                        totalIncome - totalExpenses,
                        totalIncome > totalExpenses ? PdfColors.green700 : PdfColors.red700,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Transaction Count:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                        '${monthTransactions.length}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Savings Rate:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                        '${totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome * 100).toStringAsFixed(1) : 0}%',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: totalIncome > totalExpenses ? PdfColors.green700 : PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Spending by Category
            if (categorySpending.isNotEmpty) ...[
              pw.Text(
                'SPENDING BY CATEGORY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6366F1'),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: categorySpending.entries.map((entry) {
                    final percentage = (entry.value / totalExpenses * 100);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 12),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                entry.key.displayName,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text(
                                '\$${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Stack(
                            children: [
                              pw.Container(
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey300,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                ),
                              ),
                              pw.Container(
                                height: 8,
                                width: (percentage / 100) * (PdfPageFormat.a4.width - 120),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#6366F1'),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 30),
            ],

            // Budget Performance
            if (budgetStatuses.isNotEmpty) ...[
              pw.Text(
                'BUDGET PERFORMANCE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6366F1'),
                ),
              ),
              pw.SizedBox(height: 12),
              ...budgetStatuses.map((status) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: status.isOverBudget
                      ? PdfColor.fromHex('#FEE2E2')
                      : PdfColor.fromHex('#F0FDF4'),
                  border: pw.Border.all(
                    color: status.isOverBudget
                        ? PdfColors.red300
                        : PdfColors.green300,
                    width: 1.5,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          status.budget.category.displayName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: status.isOverBudget ? PdfColors.red : PdfColors.green,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            status.isOverBudget ? 'OVER BUDGET' : 'ON TRACK',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Budget: \$${status.budget.monthlyLimit.toStringAsFixed(2)}'),
                        pw.Text('Spent: \$${status.spent.toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          status.isOverBudget
                              ? 'Over by: \$${(-status.remaining).toStringAsFixed(2)}'
                              : 'Remaining: \$${status.remaining.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: status.isOverBudget ? PdfColors.red : PdfColors.green,
                          ),
                        ),
                        pw.Text('${status.percentUsed.toStringAsFixed(1)}% used'),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Stack(
                      children: [
                        pw.Container(
                          height: 8,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                        ),
                        pw.Container(
                          height: 8,
                          width: ((status.percentUsed / 100).clamp(0, 1)) * (PdfPageFormat.a4.width - 120),
                          decoration: pw.BoxDecoration(
                            color: status.isOverBudget ? PdfColors.red : PdfColors.green,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              pw.SizedBox(height: 30),
            ],

            // Recurring Charges
            if (recurring.isNotEmpty) ...[
              pw.Text(
                'RECURRING CHARGES',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6366F1'),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Monthly Recurring:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '\$${recurring.fold(0.0, (sum, r) => sum + r.monthlyCost).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#6366F1'),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    ...recurring.map((r) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${r.merchantName} (${r.frequency.displayName})',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Text(
                            '\$${r.averageAmount.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
            ],

            // Goals
            if (goals.isNotEmpty) ...[
              pw.Text(
                'FINANCIAL GOALS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6366F1'),
                ),
              ),
              pw.SizedBox(height: 12),
              ...goals.map((goal) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: goal.isComplete
                      ? PdfColor.fromHex('#F0FDF4')
                      : PdfColor.fromHex('#F5F5F7'),
                  border: pw.Border.all(
                    color: goal.isComplete ? PdfColors.green300 : PdfColors.grey300,
                    width: 1.5,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            goal.name,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        if (goal.isComplete)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              'COMPLETED',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Goal Type: ${goal.type.displayName}', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Progress:', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(
                          '\$${goal.currentAmount.toStringAsFixed(2)} / \$${goal.targetAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Stack(
                      children: [
                        pw.Container(
                          height: 8,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                        ),
                        pw.Container(
                          height: 8,
                          width: ((goal.progressPercentage / 100).clamp(0, 1)) * (PdfPageFormat.a4.width - 120),
                          decoration: pw.BoxDecoration(
                            color: goal.isComplete ? PdfColors.green : PdfColor.fromHex('#6366F1'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Target Date: ${_formatDate(goal.targetDate)}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        if (!goal.isComplete)
                          pw.Text(
                            '${goal.daysRemaining} days remaining',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: goal.isPastDue ? PdfColors.red : PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                    if (!goal.isComplete && goal.daysRemaining > 0) ...[
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#EEF2FF'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          'Required monthly savings: \$${goal.requiredMonthlySavings.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#6366F1'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )),
            ],

            // Footer
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by Budgetly',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final filename = 'budgetly_report_${year}_$month.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
      ),
    );
  }

  // Helper method to build summary items
  pw.Widget _buildSummaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '\$${amount.abs().toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Helper method to build PDF summary
  pw.Widget _buildPdfSummary(List<Transaction> transactions) {
    final totalExpenses = transactions
        .where((t) => t.isExpense && t.spendingCategory != SpendingCategory.transfer)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = transactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount.abs());

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F5F5F7'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Income', totalIncome, PdfColors.green700),
          pw.Container(width: 1, height: 40, color: PdfColors.grey400),
          _buildSummaryItem('Total Expenses', totalExpenses, PdfColors.red700),
          pw.Container(width: 1, height: 40, color: PdfColors.grey400),
          _buildSummaryItem(
            'Net',
            totalIncome - totalExpenses,
            totalIncome > totalExpenses ? PdfColors.green700 : PdfColors.red700,
          ),
          pw.Container(width: 1, height: 40, color: PdfColors.grey400),
          pw.Column(
            children: [
              pw.Text(
                'Transactions',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${transactions.length}',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6366F1'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Save and share CSV file
  Future<void> shareCSV(String csvContent, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
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

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }
}