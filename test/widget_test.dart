import 'package:expense_tracker/core/bulk_expense_parser.dart';
import 'package:expense_tracker/core/sms_service.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:expense_tracker/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SmsService.parseDebitSms parses debit SMS and ignores credit/OTP', () {
    final nowMs = DateTime(2026, 11, 25, 10, 30).millisecondsSinceEpoch;

    final debit = SmsService.parseDebitSms(
      address: 'HDFCBK',
      body: 'Rs. 245.50 debited from A/c XX1234 to Swiggy on 25-11-26',
      dateMs: nowMs,
    );
    expect(debit, isNotNull);
    expect(debit!.amount, 245.50);
    expect(debit.merchant, contains('Swiggy'));

    final credit = SmsService.parseDebitSms(
      address: 'HDFCBK',
      body: 'Rs. 5000.00 credited to A/c XX1234 from Salary',
      dateMs: nowMs,
    );
    expect(credit, isNull);

    final otp = SmsService.parseDebitSms(
      address: 'HDFCBK',
      body: 'OTP is 123456 for txn of Rs. 500.00',
      dateMs: nowMs,
    );
    expect(otp, isNull);
  });

  test('BulkExpenseParser segregates dates, categories, totals, and others-*', () {
    const input = '''
25.11.26
Lunch ₹140
Snacks ₹100
Uber ₹100
others-soap ₹50
Total ₹340
''';
    final items = BulkExpenseParser.parse(input);
    expect(items.length, 4);
    expect(items[0].category, 'Food');
    expect(items[0].amount, 140);
    expect(items[0].date, DateTime(2026, 11, 25));
    expect(items[1].category, 'Food');
    expect(items[2].category, 'Transport');
    expect(items[3].category, 'Soap');
    expect(items[3].amount, 50);
  });

  testWidgets('SummaryCard displays total and category breakdown', (tester) async {
    const summary = ExpenseSummary(
      totalAmount: 1250.50,
      count: 2,
      byCategory: [
        CategorySummary(category: 'Food', totalAmount: 750.50, count: 1),
        CategorySummary(category: 'Transport', totalAmount: 500.00, count: 1),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SummaryCard(
            title: "Today's Spent",
            summary: summary,
            selectedCategory: null,
            onCategoryTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text("Today's Spent"), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.textContaining('1,250.50'), findsOneWidget);
    expect(find.textContaining('Food:'), findsOneWidget);
    expect(find.textContaining('Transport:'), findsOneWidget);
  });
}
