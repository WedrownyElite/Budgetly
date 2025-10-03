import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

class SubscriptionService {
  static const String _subscriptionsKey = 'managed_subscriptions';

  Future<List<ManagedSubscription>> getSubscriptions(
      List<Transaction> transactions,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);

    if (subscriptionsJson == null) return [];

    final List<dynamic> decoded = jsonDecode(subscriptionsJson);
    final recurring = RecurringTransactionDetector.detectRecurring(transactions);

    final List<ManagedSubscription> subscriptions = [];

    for (var json in decoded) {
      // Find the corresponding recurring transaction
      final merchantName = json['merchantName'] as String;
      final recurringTxn = recurring.firstWhere(
            (r) => r.merchantName.toLowerCase() == merchantName.toLowerCase(),
        orElse: () => recurring.first, // Fallback, should not happen
      );

      subscriptions.add(
        ManagedSubscription.fromJson(json, recurringTxn),
      );
    }

    return subscriptions;
  }

  Future<void> saveSubscriptions(List<ManagedSubscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(subscriptions.map((s) => s.toJson()).toList());
    await prefs.setString(_subscriptionsKey, encoded);
  }

  Future<void> addSubscription(ManagedSubscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);

    List<dynamic> decoded = [];

    if (subscriptionsJson != null) {
      decoded = jsonDecode(subscriptionsJson);
    }

    // Remove existing subscription with same merchant name
    decoded.removeWhere((s) =>
    (s['merchantName'] as String).toLowerCase() ==
        subscription.merchantName.toLowerCase()
    );

    decoded.add(subscription.toJson());

    final encoded = jsonEncode(decoded);
    await prefs.setString(_subscriptionsKey, encoded);
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);

    if (subscriptionsJson == null) return;

    final List<dynamic> decoded = jsonDecode(subscriptionsJson);
    decoded.removeWhere((s) => s['id'] == subscriptionId);

    final encoded = jsonEncode(decoded);
    await prefs.setString(_subscriptionsKey, encoded);
  }

  Future<void> updateSubscription(ManagedSubscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);

    if (subscriptionsJson == null) return;

    final List<dynamic> decoded = jsonDecode(subscriptionsJson);
    final index = decoded.indexWhere((s) => s['id'] == subscription.id);

    if (index != -1) {
      decoded[index] = subscription.toJson();
      final encoded = jsonEncode(decoded);
      await prefs.setString(_subscriptionsKey, encoded);
    }
  }

  Future<ManagedSubscription?> getSubscriptionByMerchant(
      String merchantName,
      List<Transaction> transactions,
      ) async {
    final subscriptions = await getSubscriptions(transactions);
    try {
      return subscriptions.firstWhere(
            (s) => s.merchantName.toLowerCase() == merchantName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Check if subscription exists
  Future<bool> hasSubscription(String merchantName) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionsJson = prefs.getString(_subscriptionsKey);

    if (subscriptionsJson == null) return false;

    final List<dynamic> decoded = jsonDecode(subscriptionsJson);
    return decoded.any((s) =>
    (s['merchantName'] as String).toLowerCase() == merchantName.toLowerCase()
    );
  }
}