// budgetly/lib/services/accessibility_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityService {
  /// Format currency for screen readers
  static String formatCurrencyForScreenReader(double amount, {bool isExpense = true}) {
    final absAmount = amount.abs();
    final dollars = absAmount.floor();
    final cents = ((absAmount - dollars) * 100).round();

    String formatted = '$dollars dollars';
    if (cents > 0) {
      formatted += ' and $cents cents';
    }

    if (isExpense) {
      formatted = 'expense $formatted';
    } else {
      formatted = 'income $formatted';
    }

    return formatted;
  }

  /// Format date for screen readers
  static String formatDateForScreenReader(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final transactionDate = DateTime(date.year, date.month, date.day);

      if (transactionDate == today) {
        return 'Today';
      } else if (transactionDate == yesterday) {
        return 'Yesterday';
      } else {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  /// Format percentage for screen readers
  static String formatPercentageForScreenReader(double percentage) {
    return '${percentage.toStringAsFixed(1)} percent';
  }

  /// Create semantic label for transaction
  static String transactionSemanticLabel({
    required String merchantName,
    required String category,
    required double amount,
    required bool isExpense,
    required String date,
  }) {
    return '$merchantName, $category, ${formatCurrencyForScreenReader(amount, isExpense: isExpense)}, ${formatDateForScreenReader(date)}';
  }

  /// Create semantic label for budget status
  static String budgetSemanticLabel({
    required String category,
    required double spent,
    required double limit,
    required double percentUsed,
    required bool isOverBudget,
  }) {
    final status = isOverBudget
        ? 'over budget by ${formatCurrencyForScreenReader(spent - limit)}'
        : '${formatCurrencyForScreenReader(limit - spent)} remaining';

    return '$category budget, spent ${formatCurrencyForScreenReader(spent)}, limit ${formatCurrencyForScreenReader(limit)}, ${formatPercentageForScreenReader(percentUsed)} used, $status';
  }

  /// Create semantic label for goal progress
  static String goalSemanticLabel({
    required String name,
    required String type,
    required double current,
    required double target,
    required double percentage,
    required int daysRemaining,
    required bool isComplete,
  }) {
    if (isComplete) {
      return '$name, $type, completed, ${formatCurrencyForScreenReader(current)} of ${formatCurrencyForScreenReader(target)}';
    }

    final remaining = target - current;
    return '$name, $type, ${formatPercentageForScreenReader(percentage)} complete, ${formatCurrencyForScreenReader(current)} of ${formatCurrencyForScreenReader(target)}, ${formatCurrencyForScreenReader(remaining)} remaining, $daysRemaining days left';
  }

  /// Check if reduce motion is enabled
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get appropriate animation duration based on accessibility settings
  static Duration getAnimationDuration(BuildContext context, Duration defaultDuration) {
    return shouldReduceMotion(context) ? Duration.zero : defaultDuration;
  }

  /// Announce message to screen reader
  static void announce(BuildContext context, String message, {bool assertive = false}) {
    SemanticsService.announce(
      message,
      TextDirection.ltr,
    );
  }

  /// Format large numbers for screen readers
  static String formatLargeNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)} million';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)} thousand';
    }
    return number.toStringAsFixed(2);
  }
}