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

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  bool isLoading = false;
  List<Transaction> transactions = [];
  String? accessToken;
  int _selectedIndex = 0;

  final PlaidService _plaidService = PlaidService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final token = await _storageService.getAccessToken();
    setState(() {
      accessToken = token;
      isConnected = token != null;
    });

    if (isConnected) {
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgetly'),
        actions: isConnected
            ? [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetsScreen(
                    transactions: transactions,
                  ),
                ),
              );
            },
            tooltip: 'Budgets',
          ),
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GoalsScreen(),
                ),
              );
            },
            tooltip: 'Goals',
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecurringScreen(
                    transactions: transactions,
                  ),
                ),
              );
            },
            tooltip: 'Recurring',
          ),
        ]
            : null,
      ),
      body: isConnected ? _buildConnectedView() : _buildDisconnectedView(),
      bottomNavigationBar: isConnected
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
        ],
      )
          : null,
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 16),
          const Text(
            'Disconnected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : _connectToPlaid,
            child: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Connect Bank Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Connected',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _disconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedIndex == 0
                ? TransactionListWidget(
              transactions: transactions,
              onRefresh: _fetchTransactions,
            )
                : SingleChildScrollView(
              child: SpendingChartWidget(
                transactions: transactions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}