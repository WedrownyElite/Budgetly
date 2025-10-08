// budgetly/lib/screens/transaction_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';
import '../services/cloud_sync_service.dart';
import '../services/transaction_storage_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final Function(Transaction) onTransactionUpdated;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.onTransactionUpdated,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Transaction _currentTransaction;
  final TransactionStorageService _storageService = TransactionStorageService();
  final TextEditingController _customCategoryController = TextEditingController();
  List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final categories = await _storageService.loadCustomCategories(userId);
    setState(() => _customCategories = categories);
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1F29)
                        : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Built-in categories
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Built-in Categories',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...SpendingCategory.values
                          .where((cat) => cat != SpendingCategory.transfer)
                          .map((category) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: category.group.color.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.category,
                            color: category.group.color,
                            size: 20,
                          ),
                        ),
                        title: Text(category.displayName),
                        trailing: _currentTransaction.spendingCategory == category &&
                            _currentTransaction.customCategory == null
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          _updateCategory(category, null);
                          Navigator.pop(context);
                        },
                      )),

                      // Custom categories
                      if (_customCategories.isNotEmpty) ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Custom Categories',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ..._customCategories.map((customCategory) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF6366F1),
                            child: Icon(Icons.label, color: Colors.white, size: 20),
                          ),
                          title: Text(customCategory),
                          trailing: _currentTransaction.customCategory == customCategory
                              ? const Icon(Icons.check, color: Color(0xFF6366F1))
                              : IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteCustomCategory(customCategory),
                          ),
                          onTap: () {
                            _updateCategory(_currentTransaction.spendingCategory, customCategory);
                            Navigator.pop(context);
                          },
                        )),
                      ],

                      // Add custom category
                      const Divider(),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF6366F1),
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                        title: const Text('Add Custom Category'),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddCustomCategoryDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: _customCategoryController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Pet Supplies, Gifts',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null) return;

              final categoryName = _customCategoryController.text.trim();
              if (categoryName.isNotEmpty) {
                await _storageService.addCustomCategory(categoryName, userId);
                await _loadCustomCategories();
                _customCategoryController.clear();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added "$categoryName" category')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "$category"? Transactions using this category will revert to their original category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final categories = await _storageService.loadCustomCategories(userId);
      categories.remove(category);
      await _storageService.saveCustomCategories(categories, userId);
      await _loadCustomCategories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$category" category')),
        );
      }
    }
  }

  void _updateCategory(SpendingCategory newCategory, String? customCategory) async {
    print('🔄 [UPDATE CATEGORY] Starting category update...');
    print('📝 Transaction ID: ${_currentTransaction.id}');
    print('📝 Old Category: ${_currentTransaction.spendingCategory.displayName}');
    print('📝 Old Custom Category: ${_currentTransaction.customCategory}');
    print('📝 New Category: ${newCategory.displayName}');
    print('📝 New Custom Category: $customCategory');

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('❌ [UPDATE CATEGORY] No user ID found!');
      return;
    }
    print('✅ User ID: $userId');

    setState(() {
      _currentTransaction = _currentTransaction.copyWith(
        spendingCategory: newCategory,
        customCategory: customCategory,
      );
    });
    print('✅ [UPDATE CATEGORY] Local state updated');
    print('📝 Updated transaction category: ${_currentTransaction.displayCategory}');

    try {
      // Load all transactions
      print('📂 [UPDATE CATEGORY] Loading all transactions from storage...');
      final allTransactions = await _storageService.loadTransactions(userId);
      print('✅ Loaded ${allTransactions.length} transactions');

      // Find the transaction
      final index = allTransactions.indexWhere((t) => t.id == _currentTransaction.id);
      print('🔍 Transaction index in list: $index');

      if (index != -1) {
        print('✅ [UPDATE CATEGORY] Transaction found at index $index');
        print('📝 Old transaction in list: ${allTransactions[index].displayCategory}');

        // Update the transaction
        allTransactions[index] = _currentTransaction;
        print('✅ [UPDATE CATEGORY] Transaction updated in list');
        print('📝 New transaction in list: ${allTransactions[index].displayCategory}');
        print('📝 Verify custom category: ${allTransactions[index].customCategory}');

        // Save to storage
        print('💾 [UPDATE CATEGORY] Saving transactions to storage...');
        await _storageService.saveTransactions(allTransactions, userId);
        print('✅ [UPDATE CATEGORY] Transactions saved to storage');

        // Verify save by reloading
        print('🔍 [UPDATE CATEGORY] Verifying save by reloading...');
        final reloaded = await _storageService.loadTransactions(userId);
        final reloadedIndex = reloaded.indexWhere((t) => t.id == _currentTransaction.id);
        if (reloadedIndex != -1) {
          print('✅ Verification: Transaction found after reload');
          print('📝 Reloaded category: ${reloaded[reloadedIndex].displayCategory}');
          print('📝 Reloaded custom category: ${reloaded[reloadedIndex].customCategory}');
          print('📝 Reloaded spending category: ${reloaded[reloadedIndex].spendingCategory.displayName}');
        } else {
          print('❌ Verification FAILED: Transaction not found after reload!');
        }

        // OPTIONAL: Sync to cloud if user is authenticated (not anonymous)
        if (!(FirebaseAuth.instance.currentUser?.isAnonymous ?? true)) {
          print('☁️ [UPDATE CATEGORY] Attempting cloud sync...');
          try {
            final cloudSync = CloudSyncService();
            await cloudSync.syncTransactions([_currentTransaction]);
            print('✅ [UPDATE CATEGORY] Cloud sync successful');
          } catch (e) {
            print('⚠️ [UPDATE CATEGORY] Cloud sync failed: $e');
            print('   (This is OK - local storage is primary)');
          }
        } else {
          print('ℹ️ [UPDATE CATEGORY] Skipping cloud sync (anonymous user)');
        }
      } else {
        print('❌ [UPDATE CATEGORY] Transaction NOT FOUND in list!');
        print('   Looking for ID: ${_currentTransaction.id}');
        print('   Available IDs: ${allTransactions.map((t) => t.id).take(5).join(", ")}...');
      }
    } catch (e, stackTrace) {
      print('❌ [UPDATE CATEGORY] ERROR: $e');
      print('Stack trace: $stackTrace');
    }

    // Call the callback
    print('📞 [UPDATE CATEGORY] Calling onTransactionUpdated callback...');
    widget.onTransactionUpdated(_currentTransaction);
    print('✅ [UPDATE CATEGORY] Callback completed');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category changed to "${_currentTransaction.displayCategory}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      print('✅ [UPDATE CATEGORY] SnackBar shown');
    }

    print('✅ [UPDATE CATEGORY] Update complete!');
    print('=' * 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _currentTransaction.isExpense ? 'Expense' : 'Income',
                    style: TextStyle(
                      fontSize: 14,
                      color: _currentTransaction.isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentTransaction.isExpense ? '-' : '+'}\$${_currentTransaction.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _currentTransaction.isExpense
                          ? const Color(0xFFE53E3E)
                          : const Color(0xFF48BB78),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Details Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('Merchant'),
                  subtitle: Text(_currentTransaction.merchantName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: const Text('Account'),
                  subtitle: Text(_currentTransaction.accountName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(_currentTransaction.date),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.category,
                    color: _currentTransaction.spendingCategory.group.color,
                  ),
                  title: const Text('Category'),
                  subtitle: Row(
                    children: [
                      Text(_currentTransaction.displayCategory),
                      if (_currentTransaction.customCategory != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Custom',
                            style: TextStyle(fontSize: 10, color: Color(0xFF6366F1)),
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: _showCategoryPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Plaid Categories (for reference)
          if (_currentTransaction.plaidCategories.isNotEmpty &&
              _currentTransaction.plaidCategories.first != 'Other')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plaid Categories',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _currentTransaction.plaidCategories.map((cat) {
                        return Chip(
                          label: Text(
                            cat,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Action Button
          ElevatedButton.icon(
            onPressed: _showCategoryPicker,
            icon: const Icon(Icons.edit),
            label: const Text('Change Category'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}