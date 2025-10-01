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
import '../widgets/transaction_list_widget.dart';
import '../widgets/spending_chart_widget.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'notifications_screen.dart';
import 'calendar_screen.dart';
import 'export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool isConnected = false;
  bool isLoading = false;
  List<Transaction> transactions = [];
  String? accessToken;
  int _selectedIndex = 0;
  int _notificationCount = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final PlaidService _plaidService = PlaidService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final BudgetStorageService _budgetService = BudgetStorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();

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
    final token = await _storageService.getAccessToken();
    if (mounted) {
      setState(() {
        accessToken = token;
        isConnected = token != null;
      });

      if (isConnected) {
        _fetchTransactions();
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
      setState(() {
        transactions = debugTransactions;
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

    try {
      final fetchedTransactions = await _plaidService.getTransactions(accessToken!);
      setState(() => transactions = fetchedTransactions);
      await _checkForNotifications();
    } catch (e) {
      _showError('Failed to fetch transactions');
    }
  }

  Future<void> _checkForNotifications() async {
    // Calculate budget statuses
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

    // Check for new notifications
    await _notificationService.checkForNotifications(
      budgetStatuses: budgetStatuses,
      subscriptions: subscriptions,
      goals: goals,
    );

    // Update notification count
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
                setState(() {
                  isConnected = false;
                  accessToken = null;
                  transactions.clear();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isConnected && _animationController.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleConnectionAnimation();
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF5F5F7),
      appBar: isConnected ? _buildConnectedAppBar(isDark) : null,
      body: isConnected ? _buildConnectedView(isDark) : _buildDisconnectedView(isDark),
      bottomNavigationBar: isConnected ? _buildBottomNav(isDark) : null,
    );
  }

  PreferredSizeWidget _buildConnectedAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1F29) : Colors.white,
      elevation: 0,
      title: Semantics(
        header: true,
        label: 'Budgetly app',
        child: Row(
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
      actions: [
        _buildAppBarButton(Icons.notifications, 'Notifications', isDark, () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          );
          // Reload notification count
          final notifications = await _notificationService.getNotifications();
          setState(() {
            _notificationCount = _notificationService.getUnreadCount(notifications);
          });
        }, badge: _notificationCount > 0 ? _notificationCount : null),
        _buildAppBarButton(Icons.subscriptions, 'Subscriptions', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubscriptionsScreen(transactions: transactions),
            ),
          );
        }),
        _buildAppBarButton(Icons.calendar_month, 'Calendar', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarScreen(transactions: transactions),
            ),
          );
        }),
        _buildAppBarButton(Icons.file_download, 'Export', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExportScreen(transactions: transactions),
            ),
          );
        }),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white : Colors.black87,
          ),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'budgets',
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 20),
                  SizedBox(width: 12),
                  Text('Budgets'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'goals',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Goals'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'recurring',
              child: Row(
                children: [
                  Icon(Icons.autorenew, size: 20),
                  SizedBox(width: 12),
                  Text('Recurring'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'debug',
              child: Row(
                children: [
                  Icon(Icons.bug_report, size: 20),
                  SizedBox(width: 12),
                  Text('Debug'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'budgets':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetsScreen(transactions: transactions),
                  ),
                );
                break;
              case 'goals':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GoalsScreen()),
                );
                break;
              case 'recurring':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecurringScreen(transactions: transactions),
                  ),
                );
                break;
              case 'settings':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
                break;
              case 'debug':
                _showDebugMenu();
                break;
            }
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarButton(
      IconData icon,
      String tooltip,
      bool isDark,
      VoidCallback onPressed, {
        int? badge,
      }) {
    return Semantics(
      button: true,
      label: badge != null ? '$tooltip, $badge unread' : tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.receipt_long, 'Transactions', 0, isDark),
              _buildNavItem(Icons.bar_chart_rounded, 'Analytics', 1, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    final semanticLabel = isSelected ? '$label, selected' : label;

    return Semantics(
      button: true,
      label: semanticLabel,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          AccessibilityService.announce(context, '$label selected');
        },
        child: AnimatedContainer(
          duration: AccessibilityService.getAnimationDuration(
            context,
            const Duration(milliseconds: 200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey : Colors.grey.shade600),
                size: 22,
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedView(bool isDark) {
    return Container(
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
    );
  }

  Widget _buildConnectedView(bool isDark) {
    return FadeTransition(
      opacity: AccessibilityService.shouldReduceMotion(context)
          ? const AlwaysStoppedAnimation(1.0)
          : _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1419), const Color(0xFF1A1F29)]
                : [const Color(0xFFF5F5F7), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
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
                          'Connected',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Your account is synced',
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
            ),
            Expanded(
              child: _selectedIndex == 0
                  ? TransactionListWidget(
                transactions: transactions,
                onRefresh: _fetchTransactions,
              )
                  : SingleChildScrollView(
                child: SpendingChartWidget(transactions: transactions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}