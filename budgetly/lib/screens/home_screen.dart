// budgetly/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../models/transaction.dart';
import '../services/plaid_service.dart';
import '../services/storage_service.dart';
import '../services/accessibility_service.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/spending_chart_widget.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final PlaidService _plaidService = PlaidService();
  final StorageService _storageService = StorageService();

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
    // Don't use context in initState - will check in build
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

  // Check motion preference and animate accordingly
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

  Future<void> _fetchTransactions() async {
    if (accessToken == null) return;

    try {
      final fetchedTransactions = await _plaidService.getTransactions(accessToken!);
      setState(() => transactions = fetchedTransactions);
    } catch (e) {
      _showError('Failed to fetch transactions');
    }
  }

  Future<void> _disconnect() async {
    await _storageService.deleteAccessToken();
    if (mounted) {
      // Handle animation for disconnect
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

    // Handle animation on first build if connected
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
            Flexible(
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Budgetly',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        _buildAppBarButton(Icons.account_balance_wallet, 'Budgets', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetsScreen(transactions: transactions),
            ),
          );
        }),
        _buildAppBarButton(Icons.flag_outlined, 'Goals', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoalsScreen()),
          );
        }),
        _buildAppBarButton(Icons.autorenew, 'Recurring', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecurringScreen(transactions: transactions),
            ),
          );
        }),
        _buildAppBarButton(Icons.settings, 'Settings', isDark, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        }),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarButton(IconData icon, String tooltip, bool isDark, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
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
              child: ExcludeSemantics(
                child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
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
          child: ExcludeSemantics(
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
              Semantics(
                image: true,
                label: 'Wallet icon',
                child: Container(
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                    ),
                    child: ExcludeSemantics(
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Semantics(
                header: true,
                child: Text(
                  'Welcome to Budgetly',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect your bank account to start\ntracking your finances',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              Semantics(
                button: true,
                label: isLoading
                    ? 'Connecting to bank account'
                    : 'Connect bank account securely with Plaid',
                child: Container(
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
                            ? Semantics(
                          label: 'Loading',
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                            : ExcludeSemantics(
                          child: const Row(
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
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'This connection is secured by Plaid',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Text(
                        'Secured by Plaid',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[600] : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
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
            // Connected Status Card
            Semantics(
              label: 'Bank account connected and synced',
              child: Container(
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
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF48BB78), Color(0xFF38A169)],
                          ),
                          borderRadius: BorderRadius.circular(12),
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
                      Semantics(
                        button: true,
                        label: 'Disconnect bank account',
                        child: Material(
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
                              child: ExcludeSemantics(
                                child: Text(
                                  'Disconnect',
                                  style: const TextStyle(
                                    color: Color(0xFFE53E3E),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main Content Area
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