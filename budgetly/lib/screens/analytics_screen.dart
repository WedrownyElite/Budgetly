import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../widgets/spending_chart_widget.dart';

class AnalyticsScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const AnalyticsScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: transactions.isEmpty
            ? const Center(
          child: Text('No transaction data available'),
        )
            : SingleChildScrollView(
          child: SpendingChartWidget(transactions: transactions),
        ),
      ),
    );
  }
}