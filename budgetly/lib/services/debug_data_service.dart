// budgetly/lib/services/debug_data_service.dart
import 'dart:convert';
import '../models/transaction.dart';

class DebugDataService {
  static List<Transaction> getDebugTransactions() {
    final jsonData = _debugTransactionsJson;
    final List<dynamic> decoded = jsonDecode(jsonData);
    return decoded.map((json) => Transaction.fromJson(json)).toList();
  }

  static const String _debugTransactionsJson = '''
[
  {
    "transaction_id": "txn_001",
    "account_name": "Chase Checking",
    "merchant_name": "Netflix",
    "name": "Netflix",
    "amount": 15.99,
    "date": "2025-01-05",
    "category": ["Service", "Subscription"]
  },
  {
    "transaction_id": "txn_002",
    "account_name": "Chase Checking",
    "merchant_name": "Netflix",
    "name": "Netflix",
    "amount": 15.99,
    "date": "2025-02-05",
    "category": ["Service", "Subscription"]
  },
  {
    "transaction_id": "txn_003",
    "account_name": "Chase Checking",
    "merchant_name": "Netflix",
    "name": "Netflix",
    "amount": 15.99,
    "date": "2025-03-05",
    "category": ["Service", "Subscription"]
  },
  {
    "transaction_id": "txn_004",
    "account_name": "Chase Checking",
    "merchant_name": "Netflix",
    "name": "Netflix",
    "amount": 15.99,
    "date": "2025-04-05",
    "category": ["Service", "Subscription"]
  },
  {
    "transaction_id": "txn_005",
    "account_name": "Chase Checking",
    "merchant_name": "Spotify Premium",
    "name": "Spotify",
    "amount": 10.99,
    "date": "2025-01-12",
    "category": ["Recreation", "Streaming"]
  },
  {
    "transaction_id": "txn_006",
    "account_name": "Chase Checking",
    "merchant_name": "Spotify Premium",
    "name": "Spotify",
    "amount": 10.99,
    "date": "2025-02-12",
    "category": ["Recreation", "Streaming"]
  },
  {
    "transaction_id": "txn_007",
    "account_name": "Chase Checking",
    "merchant_name": "Spotify Premium",
    "name": "Spotify",
    "amount": 10.99,
    "date": "2025-03-12",
    "category": ["Recreation", "Streaming"]
  },
  {
    "transaction_id": "txn_008",
    "account_name": "Chase Checking",
    "merchant_name": "Spotify Premium",
    "name": "Spotify",
    "amount": 10.99,
    "date": "2025-04-12",
    "category": ["Recreation", "Streaming"]
  },
  {
    "transaction_id": "txn_009",
    "account_name": "Chase Checking",
    "merchant_name": "Planet Fitness",
    "name": "Planet Fitness",
    "amount": 24.99,
    "date": "2025-01-01",
    "category": ["Recreation", "Gyms and Fitness"]
  },
  {
    "transaction_id": "txn_010",
    "account_name": "Chase Checking",
    "merchant_name": "Planet Fitness",
    "name": "Planet Fitness",
    "amount": 24.99,
    "date": "2025-02-01",
    "category": ["Recreation", "Gyms and Fitness"]
  },
  {
    "transaction_id": "txn_011",
    "account_name": "Chase Checking",
    "merchant_name": "Planet Fitness",
    "name": "Planet Fitness",
    "amount": 24.99,
    "date": "2025-03-01",
    "category": ["Recreation", "Gyms and Fitness"]
  },
  {
    "transaction_id": "txn_012",
    "account_name": "Chase Checking",
    "merchant_name": "Planet Fitness",
    "name": "Planet Fitness",
    "amount": 24.99,
    "date": "2025-04-01",
    "category": ["Recreation", "Gyms and Fitness"]
  },
  {
    "transaction_id": "txn_013",
    "account_name": "Chase Checking",
    "merchant_name": "Comcast Internet",
    "name": "Comcast",
    "amount": 79.99,
    "date": "2025-01-15",
    "category": ["Service", "Telecommunication"]
  },
  {
    "transaction_id": "txn_014",
    "account_name": "Chase Checking",
    "merchant_name": "Comcast Internet",
    "name": "Comcast",
    "amount": 79.99,
    "date": "2025-02-15",
    "category": ["Service", "Telecommunication"]
  },
  {
    "transaction_id": "txn_015",
    "account_name": "Chase Checking",
    "merchant_name": "Comcast Internet",
    "name": "Comcast",
    "amount": 79.99,
    "date": "2025-03-15",
    "category": ["Service", "Telecommunication"]
  },
  {
    "transaction_id": "txn_016",
    "account_name": "Chase Checking",
    "merchant_name": "Comcast Internet",
    "name": "Comcast",
    "amount": 79.99,
    "date": "2025-04-15",
    "category": ["Service", "Telecommunication"]
  },
  {
    "transaction_id": "txn_017",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 5.75,
    "date": "2025-04-01",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_018",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 6.25,
    "date": "2025-04-03",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_019",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 5.50,
    "date": "2025-04-08",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_020",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 87.34,
    "date": "2025-04-02",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_021",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 92.18,
    "date": "2025-04-09",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_022",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 78.45,
    "date": "2025-04-16",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_023",
    "account_name": "Chase Checking",
    "merchant_name": "Chipotle",
    "name": "Chipotle",
    "amount": 12.50,
    "date": "2025-04-04",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_024",
    "account_name": "Chase Checking",
    "merchant_name": "Chipotle",
    "name": "Chipotle",
    "amount": 13.75,
    "date": "2025-04-11",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_025",
    "account_name": "Chase Checking",
    "merchant_name": "Uber",
    "name": "Uber",
    "amount": 18.50,
    "date": "2025-04-05",
    "category": ["Travel", "Ride Share"]
  },
  {
    "transaction_id": "txn_026",
    "account_name": "Chase Checking",
    "merchant_name": "Uber",
    "name": "Uber",
    "amount": 22.30,
    "date": "2025-04-12",
    "category": ["Travel", "Ride Share"]
  },
  {
    "transaction_id": "txn_027",
    "account_name": "Chase Checking",
    "merchant_name": "Shell Gas Station",
    "name": "Shell",
    "amount": 45.00,
    "date": "2025-04-06",
    "category": ["Transportation", "Gas"]
  },
  {
    "transaction_id": "txn_028",
    "account_name": "Chase Checking",
    "merchant_name": "Shell Gas Station",
    "name": "Shell",
    "amount": 48.75,
    "date": "2025-04-20",
    "category": ["Transportation", "Gas"]
  },
  {
    "transaction_id": "txn_029",
    "account_name": "Chase Checking",
    "merchant_name": "Amazon",
    "name": "Amazon",
    "amount": 34.99,
    "date": "2025-04-07",
    "category": ["Shops", "Online Shopping"]
  },
  {
    "transaction_id": "txn_030",
    "account_name": "Chase Checking",
    "merchant_name": "Amazon",
    "name": "Amazon",
    "amount": 67.50,
    "date": "2025-04-14",
    "category": ["Shops", "Online Shopping"]
  },
  {
    "transaction_id": "txn_031",
    "account_name": "Chase Checking",
    "merchant_name": "Target",
    "name": "Target",
    "amount": 125.67,
    "date": "2025-04-08",
    "category": ["Shops", "General Merchandise"]
  },
  {
    "transaction_id": "txn_032",
    "account_name": "Chase Checking",
    "merchant_name": "CVS Pharmacy",
    "name": "CVS",
    "amount": 28.45,
    "date": "2025-04-10",
    "category": ["Healthcare", "Pharmacy"]
  },
  {
    "transaction_id": "txn_033",
    "account_name": "Chase Checking",
    "merchant_name": "Olive Garden",
    "name": "Olive Garden",
    "amount": 42.80,
    "date": "2025-04-13",
    "category": ["Food and Drink", "Restaurants"]
  },
  {
    "transaction_id": "txn_034",
    "account_name": "Chase Checking",
    "merchant_name": "AMC Theaters",
    "name": "AMC",
    "amount": 35.00,
    "date": "2025-04-15",
    "category": ["Recreation", "Movies"]
  },
  {
    "transaction_id": "txn_035",
    "account_name": "Chase Checking",
    "merchant_name": "Panera Bread",
    "name": "Panera",
    "amount": 14.25,
    "date": "2025-04-17",
    "category": ["Food and Drink", "Restaurants"]
  },
  {
    "transaction_id": "txn_036",
    "account_name": "Chase Checking",
    "merchant_name": "Dunkin Donuts",
    "name": "Dunkin",
    "amount": 4.50,
    "date": "2025-04-18",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_037",
    "account_name": "Chase Checking",
    "merchant_name": "McDonald's",
    "name": "McDonald's",
    "amount": 8.99,
    "date": "2025-04-19",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_038",
    "account_name": "Chase Checking",
    "merchant_name": "Walmart",
    "name": "Walmart",
    "amount": 156.23,
    "date": "2025-04-21",
    "category": ["Shops", "General Merchandise"]
  },
  {
    "transaction_id": "txn_039",
    "account_name": "Chase Checking",
    "merchant_name": "Best Buy",
    "name": "Best Buy",
    "amount": 299.99,
    "date": "2025-04-22",
    "category": ["Shops", "Computers and Electronics"]
  },
  {
    "transaction_id": "txn_040",
    "account_name": "Chase Checking",
    "merchant_name": "Nike Store",
    "name": "Nike",
    "amount": 89.99,
    "date": "2025-04-23",
    "category": ["Shops", "Clothing and Accessories"]
  },
  {
    "transaction_id": "txn_041",
    "account_name": "Chase Checking",
    "merchant_name": "State Farm Insurance",
    "name": "State Farm",
    "amount": 125.00,
    "date": "2025-01-20",
    "category": ["Service", "Insurance"]
  },
  {
    "transaction_id": "txn_042",
    "account_name": "Chase Checking",
    "merchant_name": "State Farm Insurance",
    "name": "State Farm",
    "amount": 125.00,
    "date": "2025-02-20",
    "category": ["Service", "Insurance"]
  },
  {
    "transaction_id": "txn_043",
    "account_name": "Chase Checking",
    "merchant_name": "State Farm Insurance",
    "name": "State Farm",
    "amount": 125.00,
    "date": "2025-03-20",
    "category": ["Service", "Insurance"]
  },
  {
    "transaction_id": "txn_044",
    "account_name": "Chase Checking",
    "merchant_name": "State Farm Insurance",
    "name": "State Farm",
    "amount": 125.00,
    "date": "2025-04-20",
    "category": ["Service", "Insurance"]
  },
  {
    "transaction_id": "txn_045",
    "account_name": "Chase Checking",
    "merchant_name": "Paycheck Deposit",
    "name": "Direct Deposit",
    "amount": -3500.00,
    "date": "2025-04-01",
    "category": ["Transfer", "Deposit"]
  },
  {
    "transaction_id": "txn_046",
    "account_name": "Chase Checking",
    "merchant_name": "Paycheck Deposit",
    "name": "Direct Deposit",
    "amount": -3500.00,
    "date": "2025-04-15",
    "category": ["Transfer", "Deposit"]
  },
  {
    "transaction_id": "txn_047",
    "account_name": "Chase Checking",
    "merchant_name": "Paycheck Deposit",
    "name": "Direct Deposit",
    "amount": -3500.00,
    "date": "2025-03-01",
    "category": ["Transfer", "Deposit"]
  },
  {
    "transaction_id": "txn_048",
    "account_name": "Chase Checking",
    "merchant_name": "Paycheck Deposit",
    "name": "Direct Deposit",
    "amount": -3500.00,
    "date": "2025-03-15",
    "category": ["Transfer", "Deposit"]
  },
  {
    "transaction_id": "txn_049",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 6.00,
    "date": "2025-03-05",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_050",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 5.85,
    "date": "2025-03-12",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_051",
    "account_name": "Chase Checking",
    "merchant_name": "Starbucks",
    "name": "Starbucks",
    "amount": 6.50,
    "date": "2025-03-19",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_052",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 95.67,
    "date": "2025-03-07",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_053",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 88.23,
    "date": "2025-03-14",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_054",
    "account_name": "Chase Checking",
    "merchant_name": "Whole Foods",
    "name": "Whole Foods",
    "amount": 102.45,
    "date": "2025-03-21",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_055",
    "account_name": "Chase Checking",
    "merchant_name": "Chipotle",
    "name": "Chipotle",
    "amount": 11.99,
    "date": "2025-03-08",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_056",
    "account_name": "Chase Checking",
    "merchant_name": "Chipotle",
    "name": "Chipotle",
    "amount": 13.25,
    "date": "2025-03-15",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_057",
    "account_name": "Chase Checking",
    "merchant_name": "Chipotle",
    "name": "Chipotle",
    "amount": 12.75,
    "date": "2025-03-22",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_058",
    "account_name": "Chase Checking",
    "merchant_name": "Shell Gas Station",
    "name": "Shell",
    "amount": 42.50,
    "date": "2025-03-10",
    "category": ["Transportation", "Gas"]
  },
  {
    "transaction_id": "txn_059",
    "account_name": "Chase Checking",
    "merchant_name": "Shell Gas Station",
    "name": "Shell",
    "amount": 46.00,
    "date": "2025-03-24",
    "category": ["Transportation", "Gas"]
  },
  {
    "transaction_id": "txn_060",
    "account_name": "Chase Checking",
    "merchant_name": "Uber",
    "name": "Uber",
    "amount": 15.75,
    "date": "2025-03-11",
    "category": ["Travel", "Ride Share"]
  },
  {
    "transaction_id": "txn_061",
    "account_name": "Chase Checking",
    "merchant_name": "Uber",
    "name": "Uber",
    "amount": 19.50,
    "date": "2025-03-18",
    "category": ["Travel", "Ride Share"]
  },
  {
    "transaction_id": "txn_062",
    "account_name": "Chase Checking",
    "merchant_name": "Amazon",
    "name": "Amazon",
    "amount": 45.99,
    "date": "2025-03-13",
    "category": ["Shops", "Online Shopping"]
  },
  {
    "transaction_id": "txn_063",
    "account_name": "Chase Checking",
    "merchant_name": "Amazon",
    "name": "Amazon",
    "amount": 23.50,
    "date": "2025-03-20",
    "category": ["Shops", "Online Shopping"]
  },
  {
    "transaction_id": "txn_064",
    "account_name": "Chase Checking",
    "merchant_name": "Target",
    "name": "Target",
    "amount": 87.34,
    "date": "2025-03-16",
    "category": ["Shops", "General Merchandise"]
  },
  {
    "transaction_id": "txn_065",
    "account_name": "Chase Checking",
    "merchant_name": "Olive Garden",
    "name": "Olive Garden",
    "amount": 56.78,
    "date": "2025-03-23",
    "category": ["Food and Drink", "Restaurants"]
  },
  {
    "transaction_id": "txn_066",
    "account_name": "Chase Checking",
    "merchant_name": "CVS Pharmacy",
    "name": "CVS",
    "amount": 32.10,
    "date": "2025-03-25",
    "category": ["Healthcare", "Pharmacy"]
  },
  {
    "transaction_id": "txn_067",
    "account_name": "Chase Checking",
    "merchant_name": "Panera Bread",
    "name": "Panera",
    "amount": 15.50,
    "date": "2025-03-26",
    "category": ["Food and Drink", "Restaurants"]
  },
  {
    "transaction_id": "txn_068",
    "account_name": "Chase Checking",
    "merchant_name": "Dunkin Donuts",
    "name": "Dunkin",
    "amount": 5.25,
    "date": "2025-03-27",
    "category": ["Food and Drink", "Coffee"]
  },
  {
    "transaction_id": "txn_069",
    "account_name": "Chase Checking",
    "merchant_name": "McDonald's",
    "name": "McDonald's",
    "amount": 7.50,
    "date": "2025-03-28",
    "category": ["Food and Drink", "Fast Food"]
  },
  {
    "transaction_id": "txn_070",
    "account_name": "Chase Checking",
    "merchant_name": "Walmart",
    "name": "Walmart",
    "amount": 134.56,
    "date": "2025-03-29",
    "category": ["Shops", "General Merchandise"]
  },
  {
    "transaction_id": "txn_071",
    "account_name": "Chase Checking",
    "merchant_name": "Electric Company",
    "name": "Electric Bill",
    "amount": 95.50,
    "date": "2025-01-25",
    "category": ["Service", "Utilities"]
  },
  {
    "transaction_id": "txn_072",
    "account_name": "Chase Checking",
    "merchant_name": "Electric Company",
    "name": "Electric Bill",
    "amount": 102.30,
    "date": "2025-02-25",
    "category": ["Service", "Utilities"]
  },
  {
    "transaction_id": "txn_073",
    "account_name": "Chase Checking",
    "merchant_name": "Electric Company",
    "name": "Electric Bill",
    "amount": 89.75,
    "date": "2025-03-25",
    "category": ["Service", "Utilities"]
  },
  {
    "transaction_id": "txn_074",
    "account_name": "Chase Checking",
    "merchant_name": "Electric Company",
    "name": "Electric Bill",
    "amount": 94.20,
    "date": "2025-04-25",
    "category": ["Service", "Utilities"]
  },
  {
    "transaction_id": "txn_075",
    "account_name": "Chase Checking",
    "merchant_name": "Home Depot",
    "name": "Home Depot",
    "amount": 167.89,
    "date": "2025-04-24",
    "category": ["Shops", "General Merchandise"]
  },
  {
    "transaction_id": "txn_076",
    "account_name": "Chase Checking",
    "merchant_name": "Costco",
    "name": "Costco",
    "amount": 234.56,
    "date": "2025-04-25",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_077",
    "account_name": "Chase Checking",
    "merchant_name": "Trader Joe's",
    "name": "Trader Joe's",
    "amount": 67.23,
    "date": "2025-04-26",
    "category": ["Shops", "Supermarkets and Groceries"]
  },
  {
    "transaction_id": "txn_078",
    "account_name": "Chase Checking",
    "merchant_name": "Parking Meter",
    "name": "Parking",
    "amount": 8.00,
    "date": "2025-04-27",
    "category": ["Transportation", "Parking"]
  },
  {
    "transaction_id": "txn_079",
    "account_name": "Chase Checking",
    "merchant_name": "AT&T Wireless",
    "name": "AT&T",
    "amount": 65.00,
    "date": "2025-04-28",
    "category": ["Service", "Telecommunication"]
  },
  {
    "transaction_id": "txn_080",
    "account_name": "Chase Checking",
    "merchant_name": "Zara",
    "name": "Zara",
    "amount": 145.00,
    "date": "2025-04-29",
    "category": ["Shops", "Clothing and Accessories"]
  }
]
''';
}