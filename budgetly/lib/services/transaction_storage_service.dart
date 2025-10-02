import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class TransactionStorageService {
  static const String _transactionsKey = 'saved_transactions';
  static const String _customCategoriesKey = 'custom_categories';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Save all transactions to local storage
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  // Load transactions from local storage
  Future<List<Transaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);

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
      ) async {
    // Create a map of existing transactions by ID for quick lookup
    final Map<String, Transaction> transactionMap = {
      for (var t in existingTransactions) t.id: t
    };

    // Add new transactions that don't exist yet
    for (var newTransaction in newTransactions) {
      if (!transactionMap.containsKey(newTransaction.id)) {
        transactionMap[newTransaction.id] = newTransaction;
      }
      // If transaction exists, keep the existing one (preserves user edits)
    }

    // Convert back to list and sort by date (newest first)
    final mergedList = transactionMap.values.toList();
    mergedList.sort((a, b) => b.date.compareTo(a.date));

    // Save merged list
    await saveTransactions(mergedList);

    return mergedList;
  }

  // Update a single transaction (for category changes)
  Future<void> updateTransaction(
      Transaction updatedTransaction,
      List<Transaction> allTransactions,
      ) async {
    final index = allTransactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      allTransactions[index] = updatedTransaction;
      await saveTransactions(allTransactions);
    }
  }

  // Save custom categories
  Future<void> saveCustomCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customCategoriesKey, categories);
  }

  // Load custom categories
  Future<List<String>> loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customCategoriesKey) ?? [];
  }

  // Add a custom category
  Future<void> addCustomCategory(String category) async {
    final categories = await loadCustomCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      await saveCustomCategories(categories);
    }
  }

  // Save last sync timestamp
  Future<void> saveLastSyncTime(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, timestamp.toIso8601String());
  }

  // Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Clear all transaction data (for debugging/reset)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
    await prefs.remove(_lastSyncKey);
  }
}