// budgetly/lib/models/budget.dart
import 'package:flutter/material.dart';
import 'transaction.dart';

class Budget {
  final String id;
  final CategoryGroup category;
  final double monthlyLimit;
  final DateTime createdAt;

  Budget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'monthlyLimit': monthlyLimit,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      category: CategoryGroup.values.firstWhere(
            (e) => e.name == json['category'],
        orElse: () => CategoryGroup.other,
      ),
      monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Budget copyWith({
    String? id,
    CategoryGroup? category,
    double? monthlyLimit,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BudgetStatus {
  final Budget budget;
  final double spent;
  final double remaining;
  final double percentUsed;
  final bool isOverBudget;

  BudgetStatus({
    required this.budget,
    required this.spent,
  })  : remaining = budget.monthlyLimit - spent,
        percentUsed = (spent / budget.monthlyLimit * 100),
        isOverBudget = spent > budget.monthlyLimit;

  Color get statusColor {
    if (isOverBudget) return Colors.red;
    if (percentUsed > 90) return Colors.orange;
    if (percentUsed > 75) return Colors.yellow[700]!;
    return Colors.green;
  }
}