import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  debugPrint('🚀 App starting...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  bool isLoading = false;
  List<Transaction> recentTransactions = [];
  String? accessToken;

  static const String backendUrl = 'http://15.204.247.152:3001';

  @override
  void initState() {
    super.initState();
    debugPrint('📱 HomeScreen initialized');
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    debugPrint('🔍 Checking connection status...');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('plaid_access_token');

    debugPrint('💾 Stored access token: ${token != null ? "EXISTS (${token.substring(0, 10)}...)" : "NULL"}');

    setState(() {
      accessToken = token;
      isConnected = token != null;
    });

    debugPrint('✅ Connection status: ${isConnected ? "CONNECTED" : "DISCONNECTED"}');

    if (isConnected) {
      debugPrint('🔄 Fetching recent transactions...');
      _fetchRecentTransactions();
    }
  }

  Future<void> _connectToPlaid() async {
    debugPrint('🔗 Starting Plaid connection process...');
    setState(() {
      isLoading = true;
    });

    try {
      // First, get link_token from your backend
      debugPrint('📡 Step 1: Getting link token from backend...');
      final linkToken = await _getLinkToken();

      if (linkToken == null) {
        debugPrint('❌ Link token is NULL - cannot proceed');
        _showError('Failed to initialize Plaid connection');
        setState(() {
          isLoading = false;
        });
        return;
      }

      debugPrint('✅ Link token received: ${linkToken.substring(0, 20)}...');

      // Create Plaid Link Token configuration
      debugPrint('⚙️ Step 2: Creating LinkTokenConfiguration...');
      final linkTokenConfig = LinkTokenConfiguration(
        token: linkToken,
      );
      debugPrint('✅ LinkTokenConfiguration created');

      // Listen for Plaid Link events before opening
      debugPrint('👂 Step 3: Setting up event listeners...');

      PlaidLink.onSuccess.listen((success) async {
        debugPrint('🎉 SUCCESS EVENT: Public token received');
        debugPrint('   Public token: ${success.publicToken.substring(0, 20)}...');
        debugPrint('   Metadata: ${success.metadata}');

        // Exchange public token for access token via your backend
        debugPrint('🔄 Exchanging public token for access token...');
        final token = await _exchangePublicToken(success.publicToken);

        if (token != null) {
          debugPrint('✅ Access token received: ${token.substring(0, 10)}...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('plaid_access_token', token);
          debugPrint('💾 Access token saved to SharedPreferences');

          setState(() {
            accessToken = token;
            isConnected = true;
            isLoading = false;
          });

          debugPrint('🎊 Connection complete! Fetching transactions...');
          _fetchRecentTransactions();
        } else {
          debugPrint('❌ Failed to get access token');
          setState(() {
            isLoading = false;
          });
        }
      });

      PlaidLink.onExit.listen((exit) {
        debugPrint('🚪 EXIT EVENT triggered');
        debugPrint('   Error: ${exit.error?.message ?? "No error (user cancelled)"}');
        debugPrint('   Exit status: ${exit.metadata}');
        setState(() {
          isLoading = false;
        });
      });

      PlaidLink.onEvent.listen((event) {
        debugPrint('📊 EVENT: ${event.name}');
        debugPrint('   Metadata: ${event.metadata}');
      });

      debugPrint('✅ Event listeners configured');

      // Create the Plaid Link handler (must be called before open)
      debugPrint('🏗️ Step 4: Creating Plaid Link handler...');
      await PlaidLink.create(configuration: linkTokenConfig);
      debugPrint('✅ Plaid Link handler created successfully');

      // Open Plaid Link
      debugPrint('🚀 Step 5: Opening Plaid Link UI...');
      PlaidLink.open();
      debugPrint('✅ Plaid Link UI opened');

    } catch (e, stackTrace) {
      debugPrint('💥 ERROR in _connectToPlaid: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      _showError('Connection failed: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> _getLinkToken() async {
    debugPrint('📤 Making request to: $backendUrl/api/create_link_token');
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/create_link_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_name': 'Finance Tracker',
          'country_codes': ['US'],
          'language': 'en',
          'user': {'client_user_id': 'user_123'}
        }),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final linkToken = data['link_token'] as String?;
        debugPrint('✅ Link token extracted: ${linkToken != null ? "SUCCESS" : "NULL"}');
        return linkToken;
      } else {
        debugPrint('❌ Non-200 status code: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('💥 ERROR in _getLinkToken: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
    return null;
  }

  Future<String?> _exchangePublicToken(String publicToken) async {
    debugPrint('📤 Exchanging public token...');
    debugPrint('   URL: $backendUrl/api/exchange_public_token');
    debugPrint('   Public token: ${publicToken.substring(0, 20)}...');

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/exchange_public_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'public_token': publicToken}),
      );

      debugPrint('📥 Exchange response status: ${response.statusCode}');
      debugPrint('📥 Exchange response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String?;
        debugPrint('✅ Access token extracted: ${accessToken != null ? "SUCCESS" : "NULL"}');
        return accessToken;
      } else {
        debugPrint('❌ Non-200 status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('💥 ERROR in _exchangePublicToken: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
    return null;
  }

  Future<void> _fetchRecentTransactions() async {
    if (accessToken == null) {
      debugPrint('⚠️ Cannot fetch transactions: accessToken is NULL');
      return;
    }

    debugPrint('📤 Fetching transactions...');
    debugPrint('   URL: $backendUrl/api/get_transactions');
    debugPrint('   Access token: ${accessToken!.substring(0, 10)}...');

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/get_transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'count': 4,
        }),
      );

      debugPrint('📥 Transactions response status: ${response.statusCode}');
      debugPrint('📥 Transactions response body length: ${response.body.length} chars');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📊 Response data keys: ${data.keys.toList()}');

        if (data['transactions'] != null) {
          final transactionsList = data['transactions'] as List;
          debugPrint('📋 Found ${transactionsList.length} transactions');

          final transactions = transactionsList
              .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
              .toList();

          setState(() {
            recentTransactions = transactions;
          });

          debugPrint('✅ Transactions loaded successfully:');
          for (var i = 0; i < transactions.length; i++) {
            debugPrint('   ${i + 1}. ${transactions[i].merchantName} - \$${transactions[i].amount}');
          }
        } else {
          debugPrint('⚠️ No transactions array in response');
        }
      } else {
        debugPrint('❌ Non-200 status code: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('💥 ERROR in _fetchRecentTransactions: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
  }

  Future<void> _disconnect() async {
    debugPrint('🔌 Disconnecting...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('plaid_access_token');
    debugPrint('💾 Access token removed from storage');

    setState(() {
      isConnected = false;
      accessToken = null;
      recentTransactions.clear();
    });

    debugPrint('✅ Disconnected successfully');
  }

  void _showError(String message) {
    debugPrint('⚠️ Showing error to user: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building UI - isConnected: $isConnected, isLoading: $isLoading, transactions: ${recentTransactions.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Tracker'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    child: Icon(
                      isConnected ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isConnected)
                    ElevatedButton(
                      onPressed: isLoading ? null : _connectToPlaid,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Connect Bank Account'),
                    )
                  else
                    TextButton(
                      onPressed: _disconnect,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Recent Transactions
            if (isConnected) ...[
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: recentTransactions.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading transactions...'),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: recentTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = recentTransactions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text(
                            transaction.merchantName.isNotEmpty
                                ? transaction.merchantName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          transaction.merchantName.isNotEmpty
                              ? transaction.merchantName
                              : transaction.accountName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(transaction.category),
                            Text(
                              transaction.date,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '\$${transaction.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: transaction.amount > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Transaction {
  final String id;
  final String accountName;
  final String merchantName;
  final double amount;
  final String date;
  final String category;

  Transaction({
    required this.id,
    required this.accountName,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.category,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    debugPrint('📝 Parsing transaction: ${json['name'] ?? json['merchant_name'] ?? "Unknown"}');
    return Transaction(
      id: json['transaction_id'] as String? ?? '',
      accountName: json['account_name'] as String? ?? 'Unknown Account',
      merchantName: json['merchant_name'] as String? ?? json['name'] as String? ?? 'Unknown Merchant',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] as String? ?? '',
      category: (json['category'] as List?)?.first as String? ?? 'Other',
    );
  }
}