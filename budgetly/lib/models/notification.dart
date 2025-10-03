import 'package:flutter/material.dart';

enum NotificationType {
  budgetWarning,
  budgetExceeded,
  subscriptionRenewal,
  subscriptionPriceChange,
  unusedSubscription,
  goalMilestone,
  unusualSpending,
  billReminder;

  String get displayName {
    switch (this) {
      case NotificationType.budgetWarning:
        return 'Budget Warning';
      case NotificationType.budgetExceeded:
        return 'Budget Exceeded';
      case NotificationType.subscriptionRenewal:
        return 'Subscription Renewal';
      case NotificationType.subscriptionPriceChange:
        return 'Price Change';
      case NotificationType.unusedSubscription:
        return 'Unused Subscription';
      case NotificationType.goalMilestone:
        return 'Goal Milestone';
      case NotificationType.unusualSpending:
        return 'Unusual Spending';
      case NotificationType.billReminder:
        return 'Bill Reminder';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.budgetWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.budgetExceeded:
        return Icons.error_outline_rounded;
      case NotificationType.subscriptionRenewal:
        return Icons.autorenew_rounded;
      case NotificationType.subscriptionPriceChange:
        return Icons.trending_up_rounded;
      case NotificationType.unusedSubscription:
        return Icons.schedule_rounded;
      case NotificationType.goalMilestone:
        return Icons.emoji_events_rounded;
      case NotificationType.unusualSpending:
        return Icons.insights_rounded;
      case NotificationType.billReminder:
        return Icons.receipt_long_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.budgetWarning:
        return Colors.orange;
      case NotificationType.budgetExceeded:
        return Colors.red;
      case NotificationType.subscriptionRenewal:
        return Colors.blue;
      case NotificationType.subscriptionPriceChange:
        return Colors.orange;
      case NotificationType.unusedSubscription:
        return Colors.purple;
      case NotificationType.goalMilestone:
        return Colors.green;
      case NotificationType.unusualSpending:
        return Colors.amber;
      case NotificationType.billReminder:
        return Colors.indigo;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => NotificationType.unusualSpending,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}