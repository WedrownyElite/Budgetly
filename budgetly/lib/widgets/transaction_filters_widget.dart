// budgetly/lib/widgets/transaction_filters_widget.dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionFiltersWidget extends StatefulWidget {
  final List<Transaction> allTransactions;
  final Function(List<Transaction>) onFiltersChanged;

  const TransactionFiltersWidget({
    super.key,
    required this.allTransactions,
    required this.onFiltersChanged,
  });

  @override
  State<TransactionFiltersWidget> createState() => _TransactionFiltersWidgetState();
}

class _TransactionFiltersWidgetState extends State<TransactionFiltersWidget> {
  String _searchQuery = '';
  String? _selectedAccount;
  SpendingCategory? _selectedCategory;
  bool _showExpenses = true;
  bool _showIncome = true;
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> get _accounts {
    final accounts = widget.allTransactions
        .map((t) => t.accountName)
        .toSet()
        .toList();
    accounts.sort();
    return accounts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F29) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by merchant name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() => _searchQuery = '');
                  _applyFilters();
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),

          // Date Range Filter
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                      _applyFilters();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? const Color(0xFF6366F1) : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _startDate != null
                                  ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                                  : 'Any',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                      _applyFilters();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? const Color(0xFF6366F1) : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Date',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _endDate != null
                                  ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                                  : 'Any',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Chips - Now wrapped to prevent scrolling
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Account Filter
              if (_accounts.length > 1)
                FilterChip(
                  label: Text(_selectedAccount ?? 'All Accounts'),
                  selected: _selectedAccount != null,
                  onSelected: (selected) {
                    _showAccountPicker();
                  },
                  avatar: const Icon(Icons.account_balance, size: 16),
                ),

              // Category Filter
              FilterChip(
                label: Text(_selectedCategory?.displayName ?? 'All Categories'),
                selected: _selectedCategory != null,
                onSelected: (selected) {
                  _showCategoryPicker();
                },
                avatar: const Icon(Icons.category, size: 16),
              ),

              // Expense Toggle
              FilterChip(
                label: const Text('Expenses'),
                selected: _showExpenses,
                onSelected: (selected) {
                  setState(() => _showExpenses = selected);
                  _applyFilters();
                },
                avatar: Icon(
                  Icons.arrow_upward,
                  size: 16,
                  color: _showExpenses ? Colors.red : null,
                ),
              ),

              // Income Toggle
              FilterChip(
                label: const Text('Income'),
                selected: _showIncome,
                onSelected: (selected) {
                  setState(() => _showIncome = selected);
                  _applyFilters();
                },
                avatar: Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: _showIncome ? Colors.green : null,
                ),
              ),

              // Clear All Filters
              if (_hasActiveFilters())
                ActionChip(
                  label: const Text('Clear All'),
                  onPressed: _clearAllFilters,
                  avatar: const Icon(Icons.clear_all, size: 16),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedAccount != null ||
        _selectedCategory != null ||
        !_showExpenses ||
        !_showIncome ||
        _startDate != null ||
        _endDate != null;
  }

  void _showAccountPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Account'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Accounts'),
                leading: const Icon(Icons.select_all),
                selected: _selectedAccount == null,
                onTap: () {
                  setState(() => _selectedAccount = null);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ..._accounts.map((account) => ListTile(
                title: Text(account),
                leading: const Icon(Icons.account_balance),
                selected: _selectedAccount == account,
                onTap: () {
                  setState(() => _selectedAccount = account);
                  _applyFilters();
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Categories'),
                leading: const Icon(Icons.select_all),
                selected: _selectedCategory == null,
                onTap: () {
                  setState(() => _selectedCategory = null);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...SpendingCategory.values
                  .where((cat) => cat != SpendingCategory.transfer)
                  .map((category) => ListTile(
                title: Text(category.displayName),
                leading: Icon(
                  Icons.circle,
                  color: category.group.color,
                  size: 12,
                ),
                selected: _selectedCategory == category,
                onTap: () {
                  setState(() => _selectedCategory = category);
                  _applyFilters();
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedAccount = null;
      _selectedCategory = null;
      _showExpenses = true;
      _showIncome = true;
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<Transaction> filtered = widget.allTransactions;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) =>
      t.merchantName.toLowerCase().contains(query) ||
          t.displayCategory.toLowerCase().contains(query) ||
          t.accountName.toLowerCase().contains(query)
      ).toList();
    }

    // Date range filter
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((t) {
        final date = DateTime.parse(t.date);
        if (_startDate != null && date.isBefore(_startDate!)) return false;
        if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    // Account filter
    if (_selectedAccount != null) {
      filtered = filtered.where((t) => t.accountName == _selectedAccount).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.spendingCategory == _selectedCategory).toList();
    }

    // Expense/Income filter
    filtered = filtered.where((t) {
      if (t.spendingCategory == SpendingCategory.transfer) return true;
      if (t.isExpense && !_showExpenses) return false;
      if (t.isIncome && !_showIncome) return false;
      return true;
    }).toList();

    widget.onFiltersChanged(filtered);
  }
}