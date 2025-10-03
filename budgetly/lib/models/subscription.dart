import 'package:flutter/material.dart';
import 'recurring_transaction.dart';

enum SubscriptionStatus {
  active,
  cancelled,
  paused;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.paused:
        return 'Paused';
    }
  }

  Color get color {
    switch (this) {
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.cancelled:
        return Colors.red;
      case SubscriptionStatus.paused:
        return Colors.orange;
    }
  }
}

class ManagedSubscription {
  final String id;
  final String merchantName;
  final RecurringTransaction recurringTransaction;
  final SubscriptionStatus status;
  final DateTime? nextBillingDate;
  final DateTime? cancellationDate;
  final String? notes;
  final DateTime? lastUsedDate;
  final bool trackUsage;
  final String? cancellationUrl;
  final String? customerServicePhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  ManagedSubscription({
    required this.id,
    required this.merchantName,
    required this.recurringTransaction,
    required this.status,
    this.nextBillingDate,
    this.cancellationDate,
    this.notes,
    this.lastUsedDate,
    this.trackUsage = false,
    this.cancellationUrl,
    this.customerServicePhone,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUnused {
    if (!trackUsage || lastUsedDate == null) return false;
    final daysSinceUse = DateTime.now().difference(lastUsedDate!).inDays;
    return daysSinceUse > 30;
  }

  int get daysUntilNextBilling {
    if (nextBillingDate == null) return 0;
    return nextBillingDate!.difference(DateTime.now()).inDays;
  }

  bool get isDueSoon {
    return daysUntilNextBilling <= 3 && daysUntilNextBilling > 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantName': merchantName,
      'status': status.name,
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'cancellationDate': cancellationDate?.toIso8601String(),
      'notes': notes,
      'lastUsedDate': lastUsedDate?.toIso8601String(),
      'trackUsage': trackUsage,
      'cancellationUrl': cancellationUrl,
      'customerServicePhone': customerServicePhone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ManagedSubscription.fromJson(
      Map<String, dynamic> json,
      RecurringTransaction recurringTransaction,
      ) {
    return ManagedSubscription(
      id: json['id'] as String,
      merchantName: json['merchantName'] as String,
      recurringTransaction: recurringTransaction,
      status: SubscriptionStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      nextBillingDate: json['nextBillingDate'] != null
          ? DateTime.parse(json['nextBillingDate'] as String)
          : null,
      cancellationDate: json['cancellationDate'] != null
          ? DateTime.parse(json['cancellationDate'] as String)
          : null,
      notes: json['notes'] as String?,
      lastUsedDate: json['lastUsedDate'] != null
          ? DateTime.parse(json['lastUsedDate'] as String)
          : null,
      trackUsage: json['trackUsage'] as bool? ?? false,
      cancellationUrl: json['cancellationUrl'] as String?,
      customerServicePhone: json['customerServicePhone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ManagedSubscription copyWith({
    String? id,
    String? merchantName,
    RecurringTransaction? recurringTransaction,
    SubscriptionStatus? status,
    DateTime? nextBillingDate,
    DateTime? cancellationDate,
    String? notes,
    DateTime? lastUsedDate,
    bool? trackUsage,
    String? cancellationUrl,
    String? customerServicePhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManagedSubscription(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      recurringTransaction: recurringTransaction ?? this.recurringTransaction,
      status: status ?? this.status,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      cancellationDate: cancellationDate ?? this.cancellationDate,
      notes: notes ?? this.notes,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      trackUsage: trackUsage ?? this.trackUsage,
      cancellationUrl: cancellationUrl ?? this.cancellationUrl,
      customerServicePhone: customerServicePhone ?? this.customerServicePhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}