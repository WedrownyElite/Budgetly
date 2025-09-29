// budgetly/lib/models/recurring_transaction.dart
import 'transaction.dart';

enum RecurrenceFrequency {
  weekly,
  biWeekly,
  monthly,
  quarterly,
  yearly;

  String get displayName {
    switch (this) {
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.biWeekly:
        return 'Bi-weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.quarterly:
        return 'Quarterly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  double get annualMultiplier {
    switch (this) {
      case RecurrenceFrequency.weekly:
        return 52;
      case RecurrenceFrequency.biWeekly:
        return 26;
      case RecurrenceFrequency.monthly:
        return 12;
      case RecurrenceFrequency.quarterly:
        return 4;
      case RecurrenceFrequency.yearly:
        return 1;
    }
  }
}

class RecurringTransaction {
  final String merchantName;
  final SpendingCategory category;
  final double averageAmount;
  final RecurrenceFrequency frequency;
  final List<Transaction> transactions;
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;

  RecurringTransaction({
    required this.merchantName,
    required this.category,
    required this.averageAmount,
    required this.frequency,
    required this.transactions,
    required this.firstOccurrence,
    required this.lastOccurrence,
  });

  int get occurrenceCount => transactions.length;

  double get annualCost => averageAmount * frequency.annualMultiplier;

  double get monthlyCost => annualCost / 12;

  bool get isSubscription =>
      category == SpendingCategory.streaming ||
          category == SpendingCategory.subscriptions ||
          category == SpendingCategory.gym ||
          frequency == RecurrenceFrequency.monthly;

  String get description {
    if (isSubscription) {
      return 'Subscription - ${frequency.displayName}';
    }
    return 'Recurring - ${frequency.displayName}';
  }
}

class RecurringTransactionDetector {
  static List<RecurringTransaction> detectRecurring(List<Transaction> transactions) {
    final Map<String, List<Transaction>> merchantGroups = {};

    // Group by merchant
    for (var transaction in transactions) {
      if (transaction.spendingCategory == SpendingCategory.transfer) continue;
      if (!transaction.isExpense) continue;

      final key = transaction.merchantName.toLowerCase().trim();
      merchantGroups[key] = merchantGroups[key] ?? [];
      merchantGroups[key]!.add(transaction);
    }

    final List<RecurringTransaction> recurring = [];

    for (var entry in merchantGroups.entries) {
      final txns = entry.value;

      // Need at least 3 occurrences to consider it recurring
      if (txns.length < 3) continue;

      // Sort by date
      txns.sort((a, b) => a.date.compareTo(b.date));

      // Calculate average days between transactions
      final intervals = <int>[];
      for (int i = 1; i < txns.length; i++) {
        final prevDate = DateTime.parse(txns[i - 1].date);
        final currDate = DateTime.parse(txns[i].date);
        intervals.add(currDate.difference(prevDate).inDays);
      }

      if (intervals.isEmpty) continue;

      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

      // Check if intervals are consistent (within 20% variance)
      final variance = intervals.map((i) => (i - avgInterval).abs()).reduce((a, b) => a + b) / intervals.length;
      final isConsistent = (variance / avgInterval) < 0.2;

      if (!isConsistent) continue;

      // Determine frequency based on average interval
      RecurrenceFrequency? frequency;
      if (avgInterval >= 6 && avgInterval <= 8) {
        frequency = RecurrenceFrequency.weekly;
      } else if (avgInterval >= 13 && avgInterval <= 15) {
        frequency = RecurrenceFrequency.biWeekly;
      } else if (avgInterval >= 28 && avgInterval <= 32) {
        frequency = RecurrenceFrequency.monthly;
      } else if (avgInterval >= 88 && avgInterval <= 95) {
        frequency = RecurrenceFrequency.quarterly;
      } else if (avgInterval >= 360 && avgInterval <= 370) {
        frequency = RecurrenceFrequency.yearly;
      }

      if (frequency == null) continue;

      // Calculate average amount
      final avgAmount = txns.map((t) => t.amount).reduce((a, b) => a + b) / txns.length;

      recurring.add(RecurringTransaction(
        merchantName: txns.first.merchantName,
        category: txns.first.spendingCategory,
        averageAmount: avgAmount,
        frequency: frequency,
        transactions: txns,
        firstOccurrence: DateTime.parse(txns.first.date),
        lastOccurrence: DateTime.parse(txns.last.date),
      ));
    }

    // Sort by monthly cost (highest first)
    recurring.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));

    return recurring;
  }
}