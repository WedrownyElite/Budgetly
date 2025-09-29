// budgetly/lib/services/budget_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/financial_goal.dart';

class BudgetStorageService {
  static const String _budgetsKey = 'budgets';
  static const String _goalsKey = 'financial_goals';

  // Budget operations
  Future<List<Budget>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final budgetsJson = prefs.getString(_budgetsKey);

    if (budgetsJson == null) return [];

    final List<dynamic> decoded = jsonDecode(budgetsJson);
    return decoded.map((json) => Budget.fromJson(json)).toList();
  }

  Future<void> saveBudgets(List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(budgets.map((b) => b.toJson()).toList());
    await prefs.setString(_budgetsKey, encoded);
  }

  Future<void> addBudget(Budget budget) async {
    final budgets = await getBudgets();

    // Remove any existing budget for this category
    budgets.removeWhere((b) => b.category == budget.category);
    budgets.add(budget);

    await saveBudgets(budgets);
  }

  Future<void> deleteBudget(String budgetId) async {
    final budgets = await getBudgets();
    budgets.removeWhere((b) => b.id == budgetId);
    await saveBudgets(budgets);
  }

  Future<void> updateBudget(Budget budget) async {
    final budgets = await getBudgets();
    final index = budgets.indexWhere((b) => b.id == budget.id);

    if (index != -1) {
      budgets[index] = budget;
      await saveBudgets(budgets);
    }
  }

  // Goal operations
  Future<List<FinancialGoal>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getString(_goalsKey);

    if (goalsJson == null) return [];

    final List<dynamic> decoded = jsonDecode(goalsJson);
    return decoded.map((json) => FinancialGoal.fromJson(json)).toList();
  }

  Future<void> saveGoals(List<FinancialGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(goals.map((g) => g.toJson()).toList());
    await prefs.setString(_goalsKey, encoded);
  }

  Future<void> addGoal(FinancialGoal goal) async {
    final goals = await getGoals();
    goals.add(goal);
    await saveGoals(goals);
  }

  Future<void> deleteGoal(String goalId) async {
    final goals = await getGoals();
    goals.removeWhere((g) => g.id == goalId);
    await saveGoals(goals);
  }

  Future<void> updateGoal(FinancialGoal goal) async {
    final goals = await getGoals();
    final index = goals.indexWhere((g) => g.id == goal.id);

    if (index != -1) {
      goals[index] = goal;
      await saveGoals(goals);
    }
  }
}