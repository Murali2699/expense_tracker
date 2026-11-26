import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/sms_service.dart';
import '../models/expense.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';
import 'add_expense_screen.dart';

class AutoExpensesScreen extends StatefulWidget {
  const AutoExpensesScreen({super.key, required this.controller});

  final ExpenseController controller;

  @override
  State<AutoExpensesScreen> createState() => _AutoExpensesScreenState();
}

class _AutoExpensesScreenState extends State<AutoExpensesScreen> {
  List<Expense> _items = [];
  bool _loading = true;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.instance.fetchAutoExpenses();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanSms() async {
    if (!SmsService.instance.isSupported) return;
    setState(() => _scanning = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var allowed = await SmsService.instance.hasPermission();
      if (!allowed) {
        allowed = await SmsService.instance.requestPermission();
      }
      if (!allowed) {
        messenger.showSnackBar(
          const SnackBar(content: Text('SMS permission is required to scan debit alerts.')),
        );
        return;
      }

      final parsed = await SmsService.instance.scanDebitMessages();
      int imported = 0;
      for (final sms in parsed) {
        final created = await ApiClient.instance.createAutoExpense(
          expenseDate: sms.date,
          amount: sms.amount,
          merchant: sms.merchant,
          sourceHash: sms.sourceHash,
        );
        if (created) imported++;
      }

      await _load();
      await widget.controller.loadExpenses();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            imported > 0
                ? 'Imported $imported new debit expense(s).'
                : 'No new debit SMS found.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _editAutoExpense(Expense expense) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          controller: widget.controller,
          existing: expense,
        ),
      ),
    );
    if (updated == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isAndroid = SmsService.instance.isSupported;

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF112A24), Color(0xFF131A22)],
              ),
              border: Border.all(color: const Color(0xFF1E4D3E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automatic Expense Adder',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAndroid
                      ? 'Reads only outgoing bank/UPI debit SMS (ignores incoming credits). Tap Edit on any entry to set its category.'
                      : 'iOS does not allow apps to read SMS. Auto-captured expenses synced from Android or Apple Shortcuts appear here.',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                ),
                if (isAndroid) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _scanning ? null : _scanSms,
                    icon: _scanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sms_outlined, size: 18),
                    label: Text(_scanning ? 'Scanning SMS...' : 'Scan Debit SMS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF032318),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.danger))
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No auto-detected debit expenses yet.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            ..._items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.note.isNotEmpty ? item.note : 'Bank/UPI Debit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.needsReview
                              ? const Color(0xFF422006)
                              : AppTheme.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.needsReview ? 'Set Category' : item.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.needsReview
                                ? const Color(0xFFFBBF24)
                                : AppTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy').format(item.expenseDate),
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency.format(item.amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit & Set Category',
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                        onPressed: () => _editAutoExpense(item),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
