// budgetly/lib/services/custom_category_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class CustomCategory {
  final String id;
  final String name;
  final String colorHex;
  final IconData icon;
  final DateTime createdAt;

  CustomCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.icon,
    required this.createdAt,
  });

  Color get color => Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'iconCodePoint': icon.codePoint,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String,
      icon: IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CustomCategoryService {
  static const String _customCategoriesKey = 'custom_categories';

  Future<List<CustomCategory>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString(_customCategoriesKey);

    if (categoriesJson == null) return [];

    final List<dynamic> decoded = jsonDecode(categoriesJson);
    return decoded.map((json) => CustomCategory.fromJson(json)).toList();
  }

  Future<void> saveCustomCategories(List<CustomCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(categories.map((c) => c.toJson()).toList());
    await prefs.setString(_customCategoriesKey, encoded);
  }

  Future<void> addCustomCategory(CustomCategory category) async {
    final categories = await getCustomCategories();
    categories.add(category);
    await saveCustomCategories(categories);
  }

  Future<void> deleteCustomCategory(String categoryId) async {
    final categories = await getCustomCategories();
    categories.removeWhere((c) => c.id == categoryId);
    await saveCustomCategories(categories);
  }

  Future<void> updateCustomCategory(CustomCategory category) async {
    final categories = await getCustomCategories();
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      categories[index] = category;
      await saveCustomCategories(categories);
    }
  }
}