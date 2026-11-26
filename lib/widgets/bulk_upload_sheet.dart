import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/bulk_expense_parser.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';

class BulkUploadSheet extends StatefulWidget {
  const BulkUploadSheet({super.key, required this.controller});

  final ExpenseController controller;

  @override
  State<BulkUploadSheet> createState() => _BulkUploadSheetState();
}

class _BulkUploadSheetState extends State<BulkUploadSheet> {
  final _textCtrl = TextEditingController();
  bool _processing = false;
  List<ParsedBulkExpense>? _savedItems;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _processAndSave() async {
    final raw = _textCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste or type your expense lines first.');
      return;
    }

    final parsed = BulkExpenseParser.parse(raw);
    if (parsed.isEmpty) {
      setState(
        () => _error =
            'Could not find any item lines. Example:\n25.11.26\nLunch ₹140\nUber ₹100\nothers-soap ₹50',
      );
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // Brief smart-processing feel + save each entry
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 700)),
        () async {
          for (final item in parsed) {
            await widget.controller.addExpense(
              expenseDate: item.date,
              category: item.category,
              amount: item.amount,
              note: item.note,
            );
          }
        }(),
      ]);

      if (mounted) {
        setState(() {
          _processing = false;
          _savedItems = parsed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text(
                    'Smart Bulk Expense Upload',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste notes with dates & amounts (e.g. "25.11.26", "Lunch ₹140", "others-soap 50"). Totals are skipped automatically.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              if (_processing) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.accent),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.accent),
                      SizedBox(height: 14),
                      Text(
                        'Segregating categories & saving...',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_savedItems != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Saved ${_savedItems!.length} expense(s)!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._savedItems!.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${DateFormat('dd MMM').format(e.date)} • ${e.category} (${e.note})',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                currency.format(e.amount),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF032318),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ] else ...[
                TextField(
                  controller: _textCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '25.11.26\nLunch ₹140\nSnacks ₹100\nUber ₹100\nothers-soap ₹50\nTotal ₹390',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _processAndSave,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text(
                    'Categorize & Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF032318),
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
