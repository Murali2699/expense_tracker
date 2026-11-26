import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/expense.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';
import 'add_expense_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.controller,
  });

  final Expense expense;
  final ExpenseController controller;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  Map<String, String>? _authHeaders;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense.hasScreenshot) {
      ApiClient.instance.authHeaders().then((headers) {
        if (mounted) setState(() => _authHeaders = headers);
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Delete Expense?'),
        content: const Text('This expense will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await widget.controller.deleteExpense(widget.expense.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = categoryMetaFor(widget.expense.category);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateStr =
        DateFormat('EEEE, dd MMM yyyy').format(widget.expense.expenseDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Expense',
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(
                    controller: widget.controller,
                    existing: widget.expense,
                  ),
                ),
              );
              if (updated == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
          ),
          IconButton(
            onPressed: _deleting ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(meta.icon, color: meta.color),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.expense.category,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        currency.format(widget.expense.amount),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                      if (widget.expense.note.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: 10),
                        Text(
                          widget.expense.note,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.expense.hasScreenshot) ...[
                const SizedBox(height: 20),
                const Text(
                  'Screenshot',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_authHeaders == null)
                  const Center(child: CircularProgressIndicator())
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      ApiClient.instance.screenshotUrl(widget.expense.id),
                      headers: _authHeaders,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Unable to load screenshot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
