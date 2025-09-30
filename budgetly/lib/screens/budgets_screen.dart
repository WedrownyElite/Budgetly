// budgetly/lib/screens/budgets_screen.dart
import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_storage_service.dart';
import '../services/accessibility_service.dart';

class BudgetsScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const BudgetsScreen({super.key, required this.transactions});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final BudgetStorageService _storageService = BudgetStorageService();
  List<Budget> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgets = await _storageService.getBudgets();
    if (mounted) {
      setState(() {
        _budgets = budgets;
        _isLoading = false;
      });
    }
  }

  Map<CategoryGroup, double> _calculateSpendingByCategory() {
    final Map<CategoryGroup, double> spending = {};
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    for (var transaction in widget.transactions) {
      if (transaction.spendingCategory == SpendingCategory.transfer) continue;
      if (!transaction.isExpense) continue;

      final transactionDate = DateTime.parse(transaction.date);
      if (transactionDate.isBefore(firstDayOfMonth)) continue;

      final group = transaction.spendingCategory.group;
      spending[group] = (spending[group] ?? 0) + transaction.amount;
    }

    return spending;
  }

  List<BudgetStatus> _getBudgetStatuses() {
    final spending = _calculateSpendingByCategory();

    return _budgets.map((budget) {
      final spent = spending[budget.category] ?? 0;
      return BudgetStatus(budget: budget, spent: spent);
    }).toList();
  }

  void _showAddBudgetDialog() {
    CategoryGroup? selectedCategory;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Select category for budget',
              child: DropdownButtonFormField<CategoryGroup>(
                decoration: const InputDecoration(labelText: 'Category'),
                items: CategoryGroup.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) => selectedCategory = value,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Enter monthly budget limit in dollars',
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Monthly Limit',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedCategory != null && controller.text.isNotEmpty) {
                final budget = Budget(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  category: selectedCategory!,
                  monthlyLimit: double.parse(controller.text),
                  createdAt: DateTime.now(),
                );

                await _storageService.addBudget(budget);
                await _loadBudgets();

                if (context.mounted) {
                  Navigator.pop(context);
                  AccessibilityService.announce(context, 'Budget added successfully');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Budget added successfully')),
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

  void _showEditBudgetDialog(Budget budget) {
    final controller = TextEditingController(text: budget.monthlyLimit.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${budget.category.displayName} Budget'),
        content: Semantics(
          label: 'Edit monthly budget limit in dollars',
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Monthly Limit',
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _storageService.deleteBudget(budget.id);
              await _loadBudgets();
              if (context.mounted) {
                Navigator.pop(context);
                AccessibilityService.announce(context, 'Budget deleted');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Budget deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final updatedBudget = budget.copyWith(
                  monthlyLimit: double.parse(controller.text),
                );

                await _storageService.updateBudget(updatedBudget);
                await _loadBudgets();

                if (context.mounted) {
                  Navigator.pop(context);
                  AccessibilityService.announce(context, 'Budget updated successfully');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Budget updated')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Semantics(
          label: 'Loading budgets',
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final budgetStatuses = _getBudgetStatuses();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          Semantics(
            button: true,
            label: 'Add new budget',
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddBudgetDialog,
            ),
          ),
        ],
      ),
      body: budgetStatuses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No budgets set'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAddBudgetDialog,
              child: const Text('Add Your First Budget'),
            ),
          ],
        ),
      )
          : Semantics(
        label: '${budgetStatuses.length} budgets',
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: budgetStatuses.length,
          itemBuilder: (context, index) {
            return _buildBudgetCard(budgetStatuses[index]);
          },
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BudgetStatus status) {
    final semanticLabel = AccessibilityService.budgetSemanticLabel(
      category: status.budget.category.displayName,
      spent: status.spent,
      limit: status.budget.monthlyLimit,
      percentUsed: status.percentUsed,
      isOverBudget: status.isOverBudget,
    );

    return Semantics(
      button: true,
      label: '$semanticLabel, double tap to edit',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => _showEditBudgetDialog(status.budget),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          status.budget.category.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        status.isOverBudget ? Icons.warning : Icons.check_circle,
                        color: status.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Spent: \$${status.spent.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: status.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Budget: \$${status.budget.monthlyLimit.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: '${status.percentUsed.toStringAsFixed(1)} percent of budget used',
                    child: LinearProgressIndicator(
                      value: (status.percentUsed / 100).clamp(0, 1),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(status.statusColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${status.percentUsed.toStringAsFixed(1)}% used',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          status.isOverBudget
                              ? 'Over by \$${(-status.remaining).toStringAsFixed(2)}'
                              : '\$${status.remaining.toStringAsFixed(2)} remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: status.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}