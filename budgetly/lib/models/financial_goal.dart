// budgetly/lib/models/financial_goal.dart
import 'package:flutter/material.dart';

enum GoalType {
  savings,
  debtPayoff,
  purchase;

  String get displayName {
    switch (this) {
      case GoalType.savings:
        return 'Savings Goal';
      case GoalType.debtPayoff:
        return 'Debt Payoff';
      case GoalType.purchase:
        return 'Purchase Goal';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.savings:
        return Icons.savings;
      case GoalType.debtPayoff:
        return Icons.credit_card_off;
      case GoalType.purchase:
        return Icons.shopping_bag;
    }
  }
}

class FinancialGoal {
  final String id;
  final String name;
  final GoalType type;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final DateTime createdAt;

  FinancialGoal({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.createdAt,
  });

  double get progressPercentage =>
      (currentAmount / targetAmount * 100).clamp(0, 100);

  double get remainingAmount => targetAmount - currentAmount;

  int get daysRemaining => targetDate.difference(DateTime.now()).inDays;

  double get requiredMonthlySavings {
    final monthsRemaining = daysRemaining / 30;
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }

  bool get isComplete => currentAmount >= targetAmount;

  bool get isPastDue => DateTime.now().isAfter(targetDate) && !isComplete;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    return FinancialGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      type: GoalType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => GoalType.savings,
      ),
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      targetDate: DateTime.parse(json['targetDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  FinancialGoal copyWith({
    String? id,
    String? name,
    GoalType? type,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    DateTime? createdAt,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}