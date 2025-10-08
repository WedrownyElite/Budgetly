import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class TransactionStorageService {
  static const String _transactionsKey = 'saved_transactions';
  static const String _customCategoriesKey = 'custom_categories';
  static const String _lastSyncKey = 'last_sync_timestamp';

  String _getUserKey(String baseKey, String userId) {
    return '${baseKey}_$userId';
  }
  
  // Save all transactions to local storage
  Future<void> saveTransactions(List<Transaction> transactions, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_transactionsKey, userId);
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(key, jsonEncode(jsonList));
  } 

  // Load transactions from local storage
  Future<List<Transaction>> loadTransactions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_transactionsKey, userId);
    final jsonString = prefs.getString(key);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      return [];
    }
  }

  // Merge new transactions with existing ones (no duplicates)
  Future<List<Transaction>> mergeTransactions(
      List<Transaction> existingTransactions,
      List<Transaction> newTransactions,
      String userId,
      ) async {
    final Map<String, Transaction> transactionMap = {
      for (var t in existingTransactions) t.id: t
    };

    // Add new transactions, but PRESERVE existing ones (which may have user edits)
    for (var newTransaction in newTransactions) {
      if (!transactionMap.containsKey(newTransaction.id)) {
        // Only add if it doesn't exist
        transactionMap[newTransaction.id] = newTransaction;
      }
      // If it exists, keep the old one (preserves customCategory and user edits)
    }

    final mergedList = transactionMap.values.toList();
    mergedList.sort((a, b) => b.date.compareTo(a.date));

    await saveTransactions(mergedList, userId);
    return mergedList;
  }

  // Update a single transaction (for category changes)
  Future<void> updateTransaction(
      Transaction updatedTransaction,
      List<Transaction> allTransactions,
      String userId,
      ) async {
    final index = allTransactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      allTransactions[index] = updatedTransaction;
      await saveTransactions(allTransactions, userId);
    }
  }

  // Save custom categories
  Future<void> saveCustomCategories(List<String> categories, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_customCategoriesKey, userId);
    await prefs.setStringList(key, categories);
  }

  // Load custom categories
  Future<List<String>> loadCustomCategories(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_customCategoriesKey, userId);
    return prefs.getStringList(key) ?? [];
  }

  // Add a custom category
  Future<void> addCustomCategory(String category, String userId) async {
    final categories = await loadCustomCategories(userId);
    if (!categories.contains(category)) {
      categories.add(category);
      await saveCustomCategories(categories, userId);
    }
  }

  // Save last sync timestamp
  Future<void> saveLastSyncTime(DateTime timestamp, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_lastSyncKey, userId);
    await prefs.setString(key, timestamp.toIso8601String());
  }

  // Get last sync timestamp
  Future<DateTime?> getLastSyncTime(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getUserKey(_lastSyncKey, userId);
    final timestamp = prefs.getString(key);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Clear all transaction data (for debugging/reset)
  Future<void> clearAllData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getUserKey(_transactionsKey, userId));
    await prefs.remove(_getUserKey(_lastSyncKey, userId));
    await prefs.remove(_getUserKey(_customCategoriesKey, userId));
  }
}