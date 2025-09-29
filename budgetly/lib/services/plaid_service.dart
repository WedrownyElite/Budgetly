import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../models/transaction.dart';

class PlaidService {
  Future<String?> createLinkToken() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/api/create_link_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_name': 'Budgetly',
          'country_codes': ['US'],
          'language': 'en',
          'user': {'client_user_id': 'user_${DateTime.now().millisecondsSinceEpoch}'}
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['link_token'] as String?;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<String?> exchangePublicToken(String publicToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/api/exchange_public_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'public_token': publicToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'] as String?;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<List<Transaction>> getTransactions(String accessToken, {int retryCount = 0}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/api/get_transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['transactions'] != null) {
          final transactionsList = data['transactions'] as List;
          return transactionsList
              .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
              .toList();
        }
      } else if (response.statusCode == 500 && retryCount < 3) {
        final data = jsonDecode(response.body);
        final errorCode = data['details']?['error_code'];

        if (errorCode == 'PRODUCT_NOT_READY') {
          final waitSeconds = 3 * (retryCount + 1);
          await Future.delayed(Duration(seconds: waitSeconds));
          return getTransactions(accessToken, retryCount: retryCount + 1);
        }
      }
    } catch (e) {
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 3));
        return getTransactions(accessToken, retryCount: retryCount + 1);
      }
      rethrow;
    }
    return [];
  }
}