import 'package:flutter/material.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../models/transaction.dart';
import '../services/plaid_service.dart';
import '../services/storage_service.dart';
import '../widgets/transaction_list_widget.dart';
import '../widgets/spending_chart_widget.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';
import 'recurring_screen.dart';

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
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
    final token = await _storageService.getAccessToken();
    setState(() {
      accessToken = token;
      isConnected = token != null;
    });

    if (isConnected) {
      _animationController.forward();
      _fetchTransactions();
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
          setState(() {
            accessToken = token;
            isConnected = true;
            isLoading = false;
          });
          _animationController.forward();
          _fetchTransactions();
          _showSuccess('Bank account connected successfully!');
        }
      });

      PlaidLink.onExit.listen((exit) {
        if (exit.error != null) {
          _showError('Connection cancelled: ${exit.error!.message}');
        }
        setState(() => isLoading = false);
      });

      await PlaidLink.create(configuration: linkTokenConfig);
      PlaidLink.open();
    } catch (e) {
      _showError('Connection failed: $e');
      setState(() => isLoading = false);
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
    _animationController.reverse();
    setState(() {
      isConnected = false;
      accessToken = null;
      transactions.clear();
      _selectedIndex = 0;
    });
    _showSuccess('Bank account disconnected');
  }

  void _showError(String message) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: isConnected ? _buildConnectedAppBar() : null,
      body: isConnected ? _buildConnectedView() : _buildDisconnectedView(),
      bottomNavigationBar: isConnected ? _buildBottomNav() : null,
    );
  }

  PreferredSizeWidget _buildConnectedAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1F29),
      elevation: 0,
      title: Row(
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
          const Text(
            'Budgetly',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarButton(Icons.account_balance_wallet, 'Budgets', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetsScreen(transactions: transactions),
            ),
          );
        }),
        _buildAppBarButton(Icons.flag_outlined, 'Goals', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoalsScreen()),
          );
        }),
        _buildAppBarButton(Icons.autorenew, 'Recurring', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecurringScreen(transactions: transactions),
            ),
          );
        }),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF262D3D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F29),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.receipt_long, 'Transactions', 0),
              _buildNavItem(Icons.bar_chart_rounded, 'Analytics', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1419), Color(0xFF1A1F29)],
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
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
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect your bank account to start\ntracking your finances',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Secured by Plaid',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  Widget _buildConnectedView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1419), Color(0xFF1A1F29)],
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F29),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Your account is synced',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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