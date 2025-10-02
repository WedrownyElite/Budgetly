// budgetly/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/plaid_service.dart';
import '../services/storage_service.dart';
import '../services/accessibility_service.dart';
import '../services/notification_service.dart';
import '../services/budget_storage_service.dart';
import '../services/debug_data_service.dart';
import '../services/subscription_service.dart';
import '../services/transaction_storage_service.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/transaction_filters_widget.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'calendar_screen.dart';
import 'export_screen.dart';
import 'transaction_detail_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool isConnected = false;
  bool isLoading = false;
  bool isSyncing = false;
  List<Transaction> transactions = [];
  List<Transaction> filteredTransactions = [];
  String? accessToken;
  int _selectedIndex = 0;
  int _notificationCount = 0;
  bool _showFilters = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final PlaidService _plaidService = PlaidService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final BudgetStorageService _budgetService = BudgetStorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final TransactionStorageService _transactionStorage = TransactionStorageService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() => isLoading = true);

    // Load saved transactions first
    final savedTransactions = await _transactionStorage.loadTransactions();

    final token = await _storageService.getAccessToken();

    if (mounted) {
      setState(() {
        accessToken = token;
        isConnected = token != null || savedTransactions.isNotEmpty;
        transactions = savedTransactions;
        filteredTransactions = savedTransactions;
        isLoading = false;
      });

      if (isConnected) {
        _handleConnectionAnimation();

        // If we have a token, fetch new transactions
        if (token != null) {
          _fetchTransactions();
        }
      }
    }
  }

  void _handleConnectionAnimation() {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _animationController.value = 1.0;
    } else {
      _animationController.forward();
    }
  }

  Future<void> _connectToPlaid() async {
    setState(() => isLoading = true);

    try {
      final linkToken = await _plaidService.createLinkToken();
      if (linkToken == null) {
        _showError('Failed to initialize Plaid connection');
        setState(() => isLoading = false);
        return;
      }

      final linkTokenConfig = LinkTokenConfiguration(token: linkToken);

      PlaidLink.onSuccess.listen((success) async {
        final token = await _plaidService.exchangePublicToken(success.publicToken);
        if (token != null) {
          await _storageService.saveAccessToken(token);
          if (mounted) {
            setState(() {
              accessToken = token;
              isConnected = true;
              isLoading = false;
            });
            _handleConnectionAnimation();
            _fetchTransactions();
            _showSuccess('Bank account connected successfully!');
          }
        }
      });

      PlaidLink.onExit.listen((exit) {
        if (exit.error != null) {
          _showError('Connection cancelled: ${exit.error!.message}');
        }
        if (mounted) {
          setState(() => isLoading = false);
        }
      });

      await PlaidLink.create(configuration: linkTokenConfig);
      PlaidLink.open();
    } catch (e) {
      _showError('Connection failed: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadDebugData() async {
    setState(() => isLoading = true);

    try {
      final debugTransactions = DebugDataService.getDebugTransactions();

      // Merge with existing transactions
      final merged = await _transactionStorage.mergeTransactions(
        transactions,
        debugTransactions,
      );

      setState(() {
        transactions = merged;
        filteredTransactions = merged;
        isConnected = true;
        isLoading = false;
      });

      _handleConnectionAnimation();
      await _checkForNotifications();
      _showSuccess('Debug data loaded successfully!');
    } catch (e) {
      _showError('Failed to load debug data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchTransactions() async {
    if (accessToken == null) return;

    setState(() => isSyncing = true);

    try {
      final newTransactions = await _plaidService.getTransactions(accessToken!);

      // Merge with existing saved transactions (preserving user edits)
      final merged = await _transactionStorage.mergeTransactions(
        transactions,
        newTransactions,
      );

      // Save last sync time
      await _transactionStorage.saveLastSyncTime(DateTime.now());

      setState(() {
        transactions = merged;
        filteredTransactions = merged;
        isSyncing = false;
      });

      await _checkForNotifications();

      final newCount = merged.length - transactions.length;
      if (newCount > 0) {
        _showSuccess('Synced! Found $newCount new transaction${newCount != 1 ? 's' : ''}');
      }
    } catch (e) {
      _showError('Failed to fetch transactions');
      setState(() => isSyncing = false);
    }
  }

  Future<void> _checkForNotifications() async {
    final budgets = await _budgetService.getBudgets();
    final goals = await _budgetService.getGoals();
    final subscriptions = await _subscriptionService.getSubscriptions(transactions);

    final Map<CategoryGroup, double> spending = {};
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    for (var transaction in transactions) {
      if (transaction.spendingCategory == SpendingCategory.transfer) continue;
      if (!transaction.isExpense) continue;

      final transactionDate = DateTime.parse(transaction.date);
      if (transactionDate.isBefore(firstDayOfMonth)) continue;

      final group = transaction.spendingCategory.group;
      spending[group] = (spending[group] ?? 0) + transaction.amount;
    }

    final budgetStatuses = budgets.map((budget) {
      final spent = spending[budget.category] ?? 0;
      return BudgetStatus(budget: budget, spent: spent);
    }).toList();

    await _notificationService.checkForNotifications(
      budgetStatuses: budgetStatuses,
      subscriptions: subscriptions,
      goals: goals,
    );

    final notifications = await _notificationService.getNotifications();
    setState(() {
      _notificationCount = _notificationService.getUnreadCount(notifications);
    });
  }

  Future<void> _disconnect() async {
    await _storageService.deleteAccessToken();
    if (mounted) {
      if (MediaQuery.of(context).disableAnimations) {
        _animationController.value = 0.0;
      } else {
        _animationController.reverse();
      }
      setState(() {
        isConnected = false;
        accessToken = null;
        transactions.clear();
        filteredTransactions.clear();
        _selectedIndex = 0;
      });
      _showSuccess('Bank account disconnected');
    }
  }

  void _showDebugMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Load Sample Data'),
              subtitle: const Text('80 transactions with recurring patterns'),
              onTap: () {
                Navigator.pop(context);
                _loadDebugData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Clear All Data'),
              subtitle: const Text('Reset app to initial state'),
              onTap: () async {
                Navigator.pop(context);
                await _storageService.deleteAccessToken();
                await _transactionStorage.clearAllData();
                setState(() {
                  isConnected = false;
                  accessToken = null;
                  transactions.clear();
                  filteredTransactions.clear();
                });
                _showSuccess('All data cleared');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AccessibilityService.announce(context, message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AccessibilityService.announce(context, message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF48BB78),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onTransactionTap(Transaction transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          transaction: transaction,
          onTransactionUpdated: (updatedTransaction) async {
            await _transactionStorage.updateTransaction(
              updatedTransaction,
              transactions,
            );

            // Reload transactions
            final reloaded = await _transactionStorage.loadTransactions();
            setState(() {
              transactions = reloaded;
              filteredTransactions = reloaded;
            });
          },
        ),
      ),
    );

    if (result != null) {
      // Transaction was updated
      setState(() {
        filteredTransactions = transactions;
      });
    }
  }

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0: // Home/Transactions
        return Column(
          children: [
            _buildConnectionCard(),
            if (_showFilters)
              TransactionFiltersWidget(
                allTransactions: transactions,
                onFiltersChanged: (filtered) {
                  setState(() => filteredTransactions = filtered);
                },
              ),
            Expanded(
              child: TransactionListWidget(
                transactions: filteredTransactions,
                onRefresh: _fetchTransactions,
                onTransactionTap: _onTransactionTap,
              ),
            ),
          ],
        );
      case 1: // Analytics
        return AnalyticsScreen(transactions: transactions);
      case 2: // Budgets & Goals
        return BudgetsScreen(transactions: transactions);
      case 3: // Recurring
        return RecurringScreen(transactions: transactions);
      case 4: // More
        return _buildMoreScreen();
      default:
        return Container();
    }
  }

  Widget _buildConnectionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F29) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF48BB78), Color(0xFF38A169)],
              ),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSyncing ? 'Syncing...' : 'Connected',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${transactions.length} transactions',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _showFilters
                      ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Disconnect button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _disconnect,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Disconnect',
                  style: TextStyle(
                    color: Color(0xFFE53E3E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag, color: Colors.green),
                ),
                title: const Text('Financial Goals'),
                subtitle: const Text('Track your savings and targets'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoalsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month, color: Colors.blue),
                ),
                title: const Text('Payment Calendar'),
                subtitle: const Text('View upcoming bills'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalendarScreen(transactions: transactions),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_download, color: Colors.orange),
                ),
                title: const Text('Export Data'),
                subtitle: const Text('Download reports and transactions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExportScreen(transactions: transactions),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Badge(
                    isLabelVisible: _notificationCount > 0,
                    label: Text('$_notificationCount'),
                    child: const Icon(Icons.notifications, color: Colors.red),
                  ),
                ),
                title: const Text('Notifications'),
                subtitle: Text(_notificationCount > 0
                    ? '$_notificationCount unread notifications'
                    : 'No new notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                  final notifications = await _notificationService.getNotifications();
                  setState(() {
                    _notificationCount = _notificationService.getUnreadCount(notifications);
                  });
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_upload, color: Colors.blue),
                ),
                title: const Text('Cloud Backup & Sync'),
                subtitle: const Text('Backup and sync your data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BackupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings, color: Color(0xFF6366F1)),
                ),
                title: const Text('Settings'),
                subtitle: const Text('App preferences and theme'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bug_report, color: Colors.purple),
                ),
                title: const Text('Debug'),
                subtitle: const Text('Load sample data or reset'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showDebugMenu,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isConnected && _animationController.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleConnectionAnimation();
      });
    }

    if (!isConnected) {
      return _buildDisconnectedView(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1F29) : Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 20),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Budgetly'),
              ),
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: AccessibilityService.shouldReduceMotion(context)
            ? const AlwaysStoppedAnimation(1.0)
            : _fadeAnimation,
        child: _getCurrentScreen(),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F29) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade300,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, isDark),
              _buildNavItem(Icons.bar_chart_rounded, 'Analytics', 1, isDark),
              _buildNavItem(Icons.account_balance_wallet, 'Budgets', 2, isDark),
              _buildNavItem(Icons.autorenew, 'Recurring', 3, isDark),
              _buildNavItem(Icons.more_horiz_rounded, 'More', 4, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        label: isSelected ? '$label, selected' : label,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_selectedIndex != index) {
                setState(() => _selectedIndex = index);
                AccessibilityService.announce(context, '$label selected');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (isDark ? Colors.grey : Colors.grey.shade600),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.grey : Colors.grey.shade600),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedView(bool isDark) {
    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF5F5F7),
        body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F1419), const Color(0xFF1A1F29)]
                    : [const Color(0xFFF5F5F7), Colors.white],
              ),
            ),
            child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                  Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.2),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Welcome to Budgetly',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Track subscriptions, manage budgets,\nand achieve your financial goals',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                            onTap: isLoading ? null : _connectToPlaid,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                                child: isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                    Icon(Icons.link, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                    'Connect Bank Account',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadDebugData,
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Load Sample Data (Debug)'),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Secured by Plaid',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[600] : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                  ),
                ),
            ),
        ),
    );
  }
}