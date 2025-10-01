import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Transaction Export', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Merchant', 'Category', 'Amount', 'Type'],
              data: filteredTransactions.map((t) => [
                t.date,
                t.merchantName,
                t.displayCategory,
                '\$${t.amount.abs().toStringAsFixed(2)}',
                t.isExpense ? 'Expense' : 'Income',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BUDGETLY MONTHLY REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('$monthName $year', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Income:'),
                      pw.Text('\$${totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Expenses:'),
                      pw.Text('\$${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net:'),
                      pw.Text('\$${(totalIncome - totalExpenses).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Transaction Count:'),
                      pw.Text('${monthTransactions.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Budget Performance
            if (budgetStatuses.isNotEmpty) ...[
              pw.Text('BUDGET PERFORMANCE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...budgetStatuses.map((status) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(status.budget.category.displayName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Budget: \$${status.budget.monthlyLimit.toStringAsFixed(2)}'),
                        pw.Text('Spent: \$${status.spent.toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Remaining: \$${status.remaining.toStringAsFixed(2)}'),
                        pw.Text('Status: ${status.isOverBudget ? "OVER BUDGET" : "${status.percentUsed.toStringAsFixed(0)}% used"}'),
                      ],
                    ),
                  ],
                ),
              )),
              pw.SizedBox(height: 20),
            ],

            // Recurring Charges
            if (recurring.isNotEmpty) ...[
              pw.Text('RECURRING CHARGES', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Total Monthly Recurring: \$${recurring.fold(0.0, (sum, r) => sum + r.monthlyCost).toStringAsFixed(2)}'),
              pw.SizedBox(height: 10),
              ...recurring.map((r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${r.merchantName} (${r.frequency.displayName})'),
                    pw.Text('\$${r.averageAmount.toStringAsFixed(2)}'),
                  ],
                ),
              )),
              pw.SizedBox(height: 20),
            ],

            // Goals
            if (goals.isNotEmpty) ...[
              pw.Text('FINANCIAL GOALS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...goals.map((goal) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(goal.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Progress: \$${goal.currentAmount.toStringAsFixed(2)} / \$${goal.targetAmount.toStringAsFixed(2)} (${goal.progressPercentage.toStringAsFixed(0)}%)'),
                    pw.Text('Target Date: ${goal.targetDate.toString().split(' ')[0]}'),
                    if (!goal.isComplete) ...[
                      pw.Text('Days Remaining: ${goal.daysRemaining}'),
                      pw.Text('Required Monthly: \$${goal.requiredMonthlySavings.toStringAsFixed(2)}'),
                    ] else
                      pw.Text('Status: COMPLETED', style: pw.TextStyle(color: PdfColors.green)),
                  ],
                ),
              )),
            ],
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
}