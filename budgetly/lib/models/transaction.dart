import 'package:flutter/material.dart';

class Transaction {
  final String id;
  final String accountName;
  final String merchantName;
  final double amount;
  final String date;
  final List<String> plaidCategories; // Store full category array
  final SpendingCategory spendingCategory;
  final String? customCategory; // Add custom category support

  Transaction({
    required this.id,
    required this.accountName,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.plaidCategories,
    required this.spendingCategory,
    this.customCategory,
  });

  bool get isExpense => amount > 0;
  bool get isIncome => amount < 0;

  String get displayCategory => customCategory ?? spendingCategory.displayName;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final categories = (json['category'] as List?)?.map((e) => e.toString()).toList() ?? ['Other'];
    final merchantName = json['merchant_name'] as String? ?? json['name'] as String? ?? 'Unknown';

    // Check if we have a saved spending category (user may have changed it)
    SpendingCategory spendingCategory;
    if (json['spending_category'] != null) {
      print('🔧 [fromJson] Found saved spending_category: ${json['spending_category']}');
      // Use the saved category
      spendingCategory = SpendingCategory.values.firstWhere(
            (e) => e.name == json['spending_category'],
        orElse: () => SpendingCategory.fromPlaidCategories(categories, merchantName),
      );
    } else {
      print('🔧 [fromJson] No saved spending_category, calculating from Plaid');
      // Calculate from Plaid categories (for old data or new imports)
      spendingCategory = SpendingCategory.fromPlaidCategories(categories, merchantName);
    }

    final transaction = Transaction(
      id: json['transaction_id'] as String? ?? '',
      accountName: json['account_name'] as String? ?? 'Unknown Account',
      merchantName: merchantName,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] as String? ?? '',
      plaidCategories: categories,
      spendingCategory: spendingCategory,
      customCategory: json['custom_category'] as String?,
    );

    // Debug log for specific transaction
    if (transaction.id == '1xMMP5Qk6aTmQk6B9lvBimNnNo9oBqUpJjaRR') {
      print('🔧 [fromJson] Creating transaction from JSON');
      print('📝 JSON input: $json');
      print('📝 plaidCategories: $categories');
      print('📝 merchantName: $merchantName');
      print('📝 Final spendingCategory: ${transaction.spendingCategory.displayName}');
      print('📝 customCategory: ${transaction.customCategory}');
    }

    return transaction;
  }

  Map<String, dynamic> toJson() {
    final json = {
      'transaction_id': id,
      'account_name': accountName,
      'merchant_name': merchantName,
      'name': merchantName,
      'amount': amount,
      'date': date,
      'category': plaidCategories,
      'spending_category': spendingCategory.name, // ✅ SAVE USER'S CATEGORY CHOICE
      'custom_category': customCategory,
    };

    // Debug log for specific transaction
    if (id == '1xMMP5Qk6aTmQk6B9lvBimNnNo9oBqUpJjaRR') {
      print('🔧 [toJson] Converting transaction to JSON');
      print('📝 spendingCategory: ${spendingCategory.displayName}');
      print('📝 spendingCategory.name: ${spendingCategory.name}');
      print('📝 customCategory: $customCategory');
      print('📝 JSON output: $json');
    }

    return json;
  }

  Transaction copyWith({
    String? id,
    String? accountName,
    String? merchantName,
    double? amount,
    String? date,
    List<String>? plaidCategories,
    SpendingCategory? spendingCategory,
    String? customCategory,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      plaidCategories: plaidCategories ?? this.plaidCategories,
      spendingCategory: spendingCategory ?? this.spendingCategory,
      customCategory: customCategory ?? this.customCategory,
    );
  }
}

enum SpendingCategory {
  // Transportation
  rideshare,
  taxi,
  publicTransit,
  gas,
  parking,

  // Food & Dining
  restaurants,
  fastFood,
  groceries,
  coffee,

  // Bills & Utilities
  utilities,
  internet,
  phone,
  rent,
  insurance,

  // Shopping
  onlineShopping,
  clothing,
  electronics,
  generalMerchandise,

  // Entertainment
  streaming,
  movies,
  concerts,
  sports,

  // Health
  pharmacy,
  doctor,
  gym,

  // Travel
  travel,
  hotels,
  flights,

  // Services
  subscriptions,
  professionalServices,

  // Other
  atmWithdrawal,
  transfer,
  other;

  String get displayName {
    switch (this) {
      case SpendingCategory.rideshare:
        return 'Rideshare';
      case SpendingCategory.taxi:
        return 'Taxi';
      case SpendingCategory.publicTransit:
        return 'Public Transit';
      case SpendingCategory.gas:
        return 'Gas';
      case SpendingCategory.parking:
        return 'Parking';
      case SpendingCategory.restaurants:
        return 'Restaurants';
      case SpendingCategory.fastFood:
        return 'Fast Food';
      case SpendingCategory.groceries:
        return 'Groceries';
      case SpendingCategory.coffee:
        return 'Coffee Shops';
      case SpendingCategory.utilities:
        return 'Utilities';
      case SpendingCategory.internet:
        return 'Internet';
      case SpendingCategory.phone:
        return 'Phone';
      case SpendingCategory.rent:
        return 'Rent';
      case SpendingCategory.insurance:
        return 'Insurance';
      case SpendingCategory.onlineShopping:
        return 'Online Shopping';
      case SpendingCategory.clothing:
        return 'Clothing';
      case SpendingCategory.electronics:
        return 'Electronics';
      case SpendingCategory.generalMerchandise:
        return 'Shopping';
      case SpendingCategory.streaming:
        return 'Streaming';
      case SpendingCategory.movies:
        return 'Movies';
      case SpendingCategory.concerts:
        return 'Concerts';
      case SpendingCategory.sports:
        return 'Sports';
      case SpendingCategory.pharmacy:
        return 'Pharmacy';
      case SpendingCategory.doctor:
        return 'Healthcare';
      case SpendingCategory.gym:
        return 'Fitness';
      case SpendingCategory.hotels:
        return 'Hotels';
      case SpendingCategory.travel:
        return 'Travel';
      case SpendingCategory.flights:
        return 'Flights';
      case SpendingCategory.subscriptions:
        return 'Subscriptions';
      case SpendingCategory.professionalServices:
        return 'Services';
      case SpendingCategory.atmWithdrawal:
        return 'ATM Withdrawal';
      case SpendingCategory.transfer:
        return 'Transfer';
      case SpendingCategory.other:
        return 'Other';
    }
  }

  static SpendingCategory fromPlaidCategories(List<String> categories, String merchantName) {
    final merchant = merchantName.toLowerCase();
    final fullCategory = categories.join(' > ').toLowerCase();

    // TRANSFERS & PAYMENTS (check these first)
    if (merchant.contains('credit card') && merchant.contains('payment')) {
      return SpendingCategory.transfer;
    }

    if (merchant.contains('automatic payment') || merchant.contains('intrst pymnt') ||
        merchant.contains('interest payment')) {
      return SpendingCategory.transfer;
    }

    if (merchant.contains('ach electronic') || merchant.contains('gusto') ||
        merchant.contains('payroll')) {
      return SpendingCategory.transfer;
    }

    if (merchant.contains('cd deposit') || merchant.contains('deposit')) {
      return SpendingCategory.transfer;
    }

    if (merchant.contains('united airlines')) {
      return SpendingCategory.flights;
    }

    // SPECIFIC MERCHANTS
    if (merchant.contains('bicycle') || merchant.contains('bike shop')) {
      return SpendingCategory.sports;
    }

    if (merchant.contains('tectra inc')) {
      return SpendingCategory.professionalServices;
    }

    if (merchant.contains('touchstone climbing') || merchant.contains('climbing')) {
      return SpendingCategory.gym;
    }

    if (merchant.contains('fun') && merchant.length < 10) {
      return SpendingCategory.streaming;
    }

    if (merchant.contains('uber') || merchant.contains('lyft')) {
      return SpendingCategory.rideshare;
    }

    // Fast food chains
    if (merchant.contains('kfc') || merchant.contains('mcdonald') ||
        merchant.contains('burger king') || merchant.contains('taco bell') ||
        merchant.contains('subway') || merchant.contains('wendy') ||
        merchant.contains('chick-fil-a') || merchant.contains('popeyes')) {
      return SpendingCategory.fastFood;
    }

    // Coffee shops
    if (merchant.contains('starbucks') || merchant.contains('dunkin') ||
        merchant.contains('coffee')) {
      return SpendingCategory.coffee;
    }

    // PLAID CATEGORIES
    if (fullCategory.contains('payment') || fullCategory.contains('transfer') ||
        fullCategory.contains('credit card') || fullCategory.contains('deposit')) {
      return SpendingCategory.transfer;
    }

    if (fullCategory.contains('travel > taxi') || fullCategory.contains('travel > ride share')) {
      return SpendingCategory.rideshare;
    }

    if (fullCategory.contains('transportation > public transportation')) {
      return SpendingCategory.publicTransit;
    }

    if (fullCategory.contains('transportation > gas')) {
      return SpendingCategory.gas;
    }

    if (fullCategory.contains('transportation > parking')) {
      return SpendingCategory.parking;
    }

    if (fullCategory.contains('food and drink > restaurants') ||
        fullCategory.contains('restaurants')) {
      return SpendingCategory.restaurants;
    }

    if (fullCategory.contains('food and drink > fast food') ||
        fullCategory.contains('fast food')) {
      return SpendingCategory.fastFood;
    }

    if (fullCategory.contains('shops > supermarkets and groceries') ||
        fullCategory.contains('groceries')) {
      return SpendingCategory.groceries;
    }

    if (fullCategory.contains('shops > computers and electronics')) {
      return SpendingCategory.electronics;
    }

    if (fullCategory.contains('shops > clothing and accessories')) {
      return SpendingCategory.clothing;
    }

    if (fullCategory.contains('shops > sporting goods') ||
        fullCategory.contains('bicycle') || fullCategory.contains('sports')) {
      return SpendingCategory.sports;
    }

    if (fullCategory.contains('recreation > gyms and fitness')) {
      return SpendingCategory.gym;
    }

    if (fullCategory.contains('service > telecommunication')) {
      return SpendingCategory.phone;
    }

    if (fullCategory.contains('service > utilities') ||
        fullCategory.contains('bills > utilities')) {
      return SpendingCategory.utilities;
    }

    if (fullCategory.contains('service > insurance')) {
      return SpendingCategory.insurance;
    }

    if (fullCategory.contains('healthcare') || fullCategory.contains('pharmacy')) {
      return SpendingCategory.pharmacy;
    }

    if (fullCategory.contains('travel > lodging') || fullCategory.contains('hotel')) {
      return SpendingCategory.hotels;
    }

    if (fullCategory.contains('travel > airlines') || fullCategory.contains('airline')) {
      return SpendingCategory.flights;
    }

    // Check broader categories
    if (categories.first.toLowerCase() == 'shops') {
      return SpendingCategory.generalMerchandise;
    }

    if (categories.first.toLowerCase() == 'recreation') {
      return SpendingCategory.streaming;
    }

    if (categories.first.toLowerCase() == 'travel') {
      return SpendingCategory.travel;
    }

    // If Plaid doesn't know, make educated guesses based on merchant name
    if (categories.length == 1 && categories.first.toLowerCase() == 'other') {
      // Try to guess from merchant name
      if (merchant.contains('inc') || merchant.contains('llc') || merchant.contains('corp')) {
        return SpendingCategory.professionalServices;
      }

      if (merchant.contains('climbing') || merchant.contains('fitness') || merchant.contains('yoga')) {
        return SpendingCategory.gym;
      }

      if (merchant.contains('payment') || merchant.contains('pymnt')) {
        return SpendingCategory.transfer;
      }
    }

    // Debug: Uncategorized transaction
    assert(() {
      debugPrint('⚠️ UNCATEGORIZED: "$merchantName" - Categories: $categories');
      return true;
    }());

    return SpendingCategory.other;
  }

  // For grouping in charts
  CategoryGroup get group {
    switch (this) {
      case SpendingCategory.rideshare:
      case SpendingCategory.taxi:
      case SpendingCategory.publicTransit:
      case SpendingCategory.gas:
      case SpendingCategory.parking:
        return CategoryGroup.transportation;

      case SpendingCategory.restaurants:
      case SpendingCategory.fastFood:
      case SpendingCategory.coffee:
        return CategoryGroup.dining;

      case SpendingCategory.groceries:
        return CategoryGroup.groceries;

      case SpendingCategory.utilities:
      case SpendingCategory.internet:
      case SpendingCategory.phone:
      case SpendingCategory.rent:
      case SpendingCategory.insurance:
        return CategoryGroup.bills;

      case SpendingCategory.onlineShopping:
      case SpendingCategory.clothing:
      case SpendingCategory.electronics:
      case SpendingCategory.generalMerchandise:
        return CategoryGroup.shopping;

      case SpendingCategory.streaming:
      case SpendingCategory.movies:
      case SpendingCategory.concerts:
      case SpendingCategory.sports:
      case SpendingCategory.gym:
        return CategoryGroup.entertainment;

      case SpendingCategory.pharmacy:
      case SpendingCategory.doctor:
        return CategoryGroup.healthcare;

      case SpendingCategory.hotels:
      case SpendingCategory.flights:
      case SpendingCategory.travel:
        return CategoryGroup.travel;

      case SpendingCategory.subscriptions:
      case SpendingCategory.professionalServices:
      case SpendingCategory.atmWithdrawal:
      case SpendingCategory.transfer:
      case SpendingCategory.other:
        return CategoryGroup.other;
    }
  }
}

enum CategoryGroup {
  transportation,
  dining,
  groceries,
  bills,
  shopping,
  entertainment,
  healthcare,
  travel,
  other;

  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }

  Color get color {
    switch (this) {
      case CategoryGroup.transportation:
        return Colors.blue;
      case CategoryGroup.dining:
        return Colors.red;
      case CategoryGroup.groceries:
        return Colors.green;
      case CategoryGroup.bills:
        return Colors.orange;
      case CategoryGroup.shopping:
        return Colors.pink;
      case CategoryGroup.entertainment:
        return Colors.purple;
      case CategoryGroup.healthcare:
        return Colors.teal;
      case CategoryGroup.travel:
        return Colors.indigo;
      case CategoryGroup.other:
        return Colors.grey;
    }
  }
}