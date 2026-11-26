import 'package:flutter/material.dart';

class Expense {
  const Expense({
    required this.id,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.note,
    required this.hasScreenshot,
    required this.createdAt,
    this.source = 'MANUAL',
    this.needsReview = false,
  });

  final String id;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String note;
  final bool hasScreenshot;
  final DateTime createdAt;
  final String source;
  final bool needsReview;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: (json['note'] as String?) ?? '',
      hasScreenshot: (json['hasScreenshot'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      source: (json['source'] as String?) ?? 'MANUAL',
      needsReview: (json['needsReview'] as bool?) ?? false,
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  final String category;
  final double totalAmount;
  final int count;

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: json['category'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      count: (json['count'] as num).toInt(),
    );
  }
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.totalAmount,
    required this.count,
    required this.byCategory,
  });

  const ExpenseSummary.empty()
      : totalAmount = 0,
        count = 0,
        byCategory = const [];

  final double totalAmount;
  final int count;
  final List<CategorySummary> byCategory;

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['byCategory'] as List<dynamic>? ?? [])
        .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return ExpenseSummary(
      totalAmount: (json['totalAmount'] as num).toDouble(),
      count: (json['count'] as num).toInt(),
      byCategory: list,
    );
  }
}

enum DateFilterPreset {
  today,
  yesterday,
  thisMonth,
  selectedMonth,
  customRange,
  all,
}

class CategoryMeta {
  const CategoryMeta(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

const List<CategoryMeta> kDefaultCategories = [
  CategoryMeta('Food', Icons.restaurant_rounded, Color(0xFFFF7A59)),
  CategoryMeta('Groceries', Icons.shopping_basket_rounded, Color(0xFF2EC4B6)),
  CategoryMeta('Transport', Icons.directions_car_rounded, Color(0xFF4EA8DE)),
  CategoryMeta('Bills', Icons.receipt_long_rounded, Color(0xFFF4A261)),
  CategoryMeta('Shopping', Icons.shopping_bag_rounded, Color(0xFFE76F51)),
  CategoryMeta('Health', Icons.favorite_rounded, Color(0xFFEF476F)),
  CategoryMeta('Entertainment', Icons.movie_rounded, Color(0xFF9B5DE5)),
  CategoryMeta('Other', Icons.category_rounded, Color(0xFF94A3B8)),
];

CategoryMeta categoryMetaFor(String name) {
  final lower = name.trim().toLowerCase();
  if (lower == 'bank/upi' || lower == 'auto') {
    return const CategoryMeta(
      'Bank/UPI',
      Icons.account_balance_wallet_rounded,
      Color(0xFF10B981),
    );
  }
  for (final cat in kDefaultCategories) {
    if (cat.name.toLowerCase() == lower) return cat;
  }
  return kDefaultCategories.last;
}
