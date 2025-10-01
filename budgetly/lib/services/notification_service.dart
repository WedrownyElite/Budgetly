import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../models/budget.dart';
import '../models/subscription.dart';
import '../models/financial_goal.dart';

class NotificationService {
  static const String _notificationsKey = 'app_notifications';
  static const String _lastCheckKey = 'last_notification_check';

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString(_notificationsKey);

    if (notificationsJson == null) return [];

    final List<dynamic> decoded = jsonDecode(notificationsJson);
    final notifications = decoded
        .map((json) => AppNotification.fromJson(json))
        .toList();

    // Sort by date, newest first
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notifications;
  }

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_notificationsKey, encoded);
  }

  Future<void> addNotification(AppNotification notification) async {
    final notifications = await getNotifications();
    notifications.insert(0, notification);

    // Keep only last 100 notifications
    if (notifications.length > 100) {
      notifications.removeRange(100, notifications.length);
    }

    await saveNotifications(notifications);
  }

  Future<void> markAsRead(String notificationId) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == notificationId);

    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      await saveNotifications(notifications);
    }
  }

  Future<void> markAllAsRead() async {
    final notifications = await getNotifications();
    final updated = notifications.map((n) => n.copyWith(isRead: true)).toList();
    await saveNotifications(updated);
  }

  Future<void> deleteNotification(String notificationId) async {
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == notificationId);
    await saveNotifications(notifications);
  }

  Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }

  int getUnreadCount(List<AppNotification> notifications) {
    return notifications.where((n) => !n.isRead).length;
  }

  // Check for new notifications
  Future<List<AppNotification>> checkForNotifications({
    required List<BudgetStatus> budgetStatuses,
    required List<ManagedSubscription> subscriptions,
    required List<FinancialGoal> goals,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastCheckKey);
    final now = DateTime.now();

    // Only check once per day
    if (lastCheck != null) {
      final lastCheckDate = DateTime.parse(lastCheck);
      if (now.difference(lastCheckDate).inHours < 24) {
        return [];
      }
    }

    final newNotifications = <AppNotification>[];

    // Check budgets
    for (var status in budgetStatuses) {
      if (status.isOverBudget) {
        newNotifications.add(AppNotification(
          id: 'budget_exceeded_${status.budget.id}_${now.millisecondsSinceEpoch}',
          type: NotificationType.budgetExceeded,
          title: 'Budget Exceeded',
          message: 'You\'ve exceeded your ${status.budget.category.displayName} budget by \$${(-status.remaining).toStringAsFixed(2)}',
          createdAt: now,
          metadata: {'budgetId': status.budget.id},
        ));
      } else if (status.percentUsed >= 90) {
        newNotifications.add(AppNotification(
          id: 'budget_warning_${status.budget.id}_${now.millisecondsSinceEpoch}',
          type: NotificationType.budgetWarning,
          title: 'Budget Warning',
          message: 'You\'ve used ${status.percentUsed.toStringAsFixed(0)}% of your ${status.budget.category.displayName} budget',
          createdAt: now,
          metadata: {'budgetId': status.budget.id},
        ));
      }
    }

    // Check subscriptions
    for (var subscription in subscriptions) {
      if (subscription.status == SubscriptionStatus.active) {
        if (subscription.isDueSoon) {
          newNotifications.add(AppNotification(
            id: 'subscription_renewal_${subscription.id}_${now.millisecondsSinceEpoch}',
            type: NotificationType.subscriptionRenewal,
            title: 'Subscription Renewal',
            message: '${subscription.merchantName} will renew in ${subscription.daysUntilNextBilling} days (\$${subscription.recurringTransaction.averageAmount.toStringAsFixed(2)})',
            createdAt: now,
            metadata: {'subscriptionId': subscription.id},
          ));
        }

        if (subscription.isUnused) {
          newNotifications.add(AppNotification(
            id: 'unused_subscription_${subscription.id}_${now.millisecondsSinceEpoch}',
            type: NotificationType.unusedSubscription,
            title: 'Unused Subscription',
            message: 'You haven\'t used ${subscription.merchantName} in over 30 days. Consider cancelling to save \$${subscription.recurringTransaction.monthlyCost.toStringAsFixed(2)}/month',
            createdAt: now,
            metadata: {'subscriptionId': subscription.id},
          ));
        }
      }
    }

    // Check goals
    for (var goal in goals) {
      if (!goal.isComplete) {
        final milestones = [25.0, 50.0, 75.0, 90.0];
        for (var milestone in milestones) {
          if (goal.progressPercentage >= milestone &&
              goal.progressPercentage < milestone + 5) {
            newNotifications.add(AppNotification(
              id: 'goal_milestone_${goal.id}_${milestone.toInt()}_${now.millisecondsSinceEpoch}',
              type: NotificationType.goalMilestone,
              title: 'Goal Milestone',
              message: 'You\'re ${milestone.toInt()}% of the way to ${goal.name}! Keep going!',
              createdAt: now,
              metadata: {'goalId': goal.id, 'milestone': milestone},
            ));
          }
        }
      }
    }

    // Save new notifications
    for (var notification in newNotifications) {
      await addNotification(notification);
    }

    // Update last check time
    await prefs.setString(_lastCheckKey, now.toIso8601String());

    return newNotifications;
  }
}