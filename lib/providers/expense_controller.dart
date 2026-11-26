import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/expense.dart';

class ExpenseController extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  List<Expense> _expenses = [];
  ExpenseSummary _summary = const ExpenseSummary.empty();
  DateFilterPreset _datePreset = DateFilterPreset.thisMonth;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _customFrom;
  DateTime? _customTo;
  String? _selectedCategory;
  bool _isLoading = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  ExpenseSummary get summary => _summary;
  DateFilterPreset get datePreset => _datePreset;
  DateTime get selectedMonth => _selectedMonth;
  DateTime? get customFrom => _customFrom;
  DateTime? get customTo => _customTo;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get periodTitle {
    switch (_datePreset) {
      case DateFilterPreset.today:
        return "Today's Spent";
      case DateFilterPreset.yesterday:
        return "Yesterday's Spent";
      case DateFilterPreset.thisMonth:
        return '${DateFormat('MMMM yyyy').format(DateTime.now())} Spent';
      case DateFilterPreset.selectedMonth:
        return '${DateFormat('MMMM yyyy').format(_selectedMonth)} Spent';
      case DateFilterPreset.customRange:
        if (_customFrom != null && _customTo != null) {
          final f = DateFormat('dd MMM yyyy').format(_customFrom!);
          final t = DateFormat('dd MMM yyyy').format(_customTo!);
          return f == t ? '$f Spent' : '$f – $t';
        }
        return 'Custom Range Spent';
      case DateFilterPreset.all:
        return 'Total Spent';
    }
  }

  ({DateTime? from, DateTime? to}) _computeDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_datePreset) {
      case DateFilterPreset.today:
        return (from: today, to: today);
      case DateFilterPreset.yesterday:
        final yest = today.subtract(const Duration(days: 1));
        return (from: yest, to: yest);
      case DateFilterPreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (from: start, to: end);
      case DateFilterPreset.selectedMonth:
        final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
        return (from: start, to: end);
      case DateFilterPreset.customRange:
        return (from: _customFrom, to: _customTo);
      case DateFilterPreset.all:
        return (from: null, to: null);
    }
  }

  Future<void> loadExpenses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final range = _computeDateRange();
      final result = await _api.fetchExpenses(
        from: range.from,
        to: range.to,
        category: _selectedCategory,
      );
      _expenses = result.expenses;
      _summary = result.summary;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDatePreset(DateFilterPreset preset, {DateTime? month}) async {
    _datePreset = preset;
    if (month != null) {
      _selectedMonth = DateTime(month.year, month.month);
    }
    await loadExpenses();
  }

  Future<void> setCustomDateRange(DateTime from, DateTime to) async {
    _datePreset = DateFilterPreset.customRange;
    _customFrom = from;
    _customTo = to;
    await loadExpenses();
  }

  Future<void> setCategoryFilter(String? category) async {
    _selectedCategory = category;
    await loadExpenses();
  }

  Future<void> addExpense({
    required DateTime expenseDate,
    required String category,
    required double amount,
    String note = '',
    File? screenshot,
  }) async {
    await _api.createExpense(
      expenseDate: expenseDate,
      category: category,
      amount: amount,
      note: note,
      screenshot: screenshot,
    );
    await loadExpenses();
  }

  Future<void> updateExpense({
    required String id,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String note,
  }) async {
    await _api.updateExpense(
      id: id,
      expenseDate: expenseDate,
      category: category,
      amount: amount,
      note: note,
    );
    await loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await _api.deleteExpense(id);
    await loadExpenses();
  }
}
