// budgetly/lib/screens/goals_screen.dart
import 'package:flutter/material.dart';
import '../models/financial_goal.dart';
import '../services/budget_storage_service.dart';
import '../services/accessibility_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final BudgetStorageService _storageService = BudgetStorageService();
  List<FinancialGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await _storageService.getGoals();
    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final currentController = TextEditingController(text: '0');
    GoalType selectedType = GoalType.savings;
    DateTime targetDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Financial Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Enter goal name',
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Goal Name'),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Select goal type',
                  child: DropdownButtonFormField<GoalType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Goal Type'),
                    items: GoalType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(type.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Enter target amount in dollars',
                  child: TextField(
                    controller: targetController,
                    decoration: const InputDecoration(
                      labelText: 'Target Amount',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Enter current amount in dollars',
                  child: TextField(
                    controller: currentController,
                    decoration: const InputDecoration(
                      labelText: 'Current Amount',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Select target date, currently ${targetDate.month}/${targetDate.day}/${targetDate.year}',
                  child: ListTile(
                    title: const Text('Target Date'),
                    subtitle: Text('${targetDate.month}/${targetDate.day}/${targetDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setState(() => targetDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && targetController.text.isNotEmpty) {
                  final goal = FinancialGoal(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: selectedType,
                    targetAmount: double.parse(targetController.text),
                    currentAmount: double.parse(currentController.text),
                    targetDate: targetDate,
                    createdAt: DateTime.now(),
                  );

                  await _storageService.addGoal(goal);
                  await _loadGoals();

                  if (context.mounted) {
                    Navigator.pop(context);
                    AccessibilityService.announce(context, 'Goal added successfully');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Goal added successfully')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDetailsDialog(FinancialGoal goal) {
    final currentController = TextEditingController(text: goal.currentAmount.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(goal.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Goal type: ${goal.type.displayName}',
                child: Row(
                  children: [
                    Icon(goal.type.icon, size: 20),
                    const SizedBox(width: 8),
                    Text(goal.type.displayName),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Target amount: ${AccessibilityService.formatCurrencyForScreenReader(goal.targetAmount, isExpense: false)}',
                child: Text('Target: \$${goal.targetAmount.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Update current amount',
                child: TextField(
                  controller: currentController,
                  decoration: const InputDecoration(
                    labelText: 'Current Amount',
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Target date: ${AccessibilityService.formatDateForScreenReader(goal.targetDate.toIso8601String())}',
                child: Text('Target Date: ${goal.targetDate.month}/${goal.targetDate.day}/${goal.targetDate.year}'),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: goal.daysRemaining > 0
                    ? '${goal.daysRemaining} days remaining'
                    : goal.isPastDue
                    ? 'Goal is past due'
                    : 'Goal completed',
                child: Text(
                  goal.daysRemaining > 0
                      ? '${goal.daysRemaining} days remaining'
                      : 'Past due',
                  style: TextStyle(
                    color: goal.isPastDue ? Colors.red : Colors.grey[600],
                  ),
                ),
              ),
              if (!goal.isComplete && goal.daysRemaining > 0) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'To reach your goal, save ${AccessibilityService.formatCurrencyForScreenReader(goal.requiredMonthlySavings, isExpense: false)} per month',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To reach your goal:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Save \$${goal.requiredMonthlySavings.toStringAsFixed(2)}/month',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _storageService.deleteGoal(goal.id);
              await _loadGoals();
              if (context.mounted) {
                Navigator.pop(context);
                AccessibilityService.announce(context, 'Goal deleted');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Goal deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentController.text.isNotEmpty) {
                final updatedGoal = goal.copyWith(
                  currentAmount: double.parse(currentController.text),
                );

                await _storageService.updateGoal(updatedGoal);
                await _loadGoals();

                if (context.mounted) {
                  Navigator.pop(context);
                  AccessibilityService.announce(context, 'Goal updated successfully');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Goal updated')),
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
          label: 'Loading financial goals',
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Goals'),
        actions: [
          Semantics(
            button: true,
            label: 'Add new financial goal',
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddGoalDialog,
            ),
          ),
        ],
      ),
      body: _goals.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No goals yet'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAddGoalDialog,
              child: const Text('Add Your First Goal'),
            ),
          ],
        ),
      )
          : Semantics(
        label: '${_goals.length} financial goals',
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _goals.length,
          itemBuilder: (context, index) {
            final goal = _goals[index];
            return _buildGoalCard(goal);
          },
        ),
      ),
    );
  }

  Widget _buildGoalCard(FinancialGoal goal) {
    final semanticLabel = AccessibilityService.goalSemanticLabel(
      name: goal.name,
      type: goal.type.displayName,
      current: goal.currentAmount,
      target: goal.targetAmount,
      percentage: goal.progressPercentage,
      daysRemaining: goal.daysRemaining,
      isComplete: goal.isComplete,
    );

    return Semantics(
      button: true,
      label: '$semanticLabel, double tap to view details',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => _showGoalDetailsDialog(goal),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(goal.type.icon, size: 24, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (goal.isComplete)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${goal.currentAmount.toStringAsFixed(2)} / ${goal.targetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${goal.progressPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: goal.progressPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isComplete ? Colors.green : Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          goal.daysRemaining > 0
                              ? '${goal.daysRemaining} days left'
                              : goal.isComplete
                              ? 'Completed!'
                              : 'Past due',
                          style: TextStyle(
                            fontSize: 12,
                            color: goal.isPastDue
                                ? Colors.red
                                : goal.isComplete
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!goal.isComplete) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${goal.remainingAmount.toStringAsFixed(2)} to go',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
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