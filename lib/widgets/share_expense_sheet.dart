import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/contact_picker.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

enum _SharePeriodMode { singleDate, customMonth, monthRange }

class ShareExpenseSheet extends StatefulWidget {
  const ShareExpenseSheet({super.key});

  @override
  State<ShareExpenseSheet> createState() => _ShareExpenseSheetState();
}

class _ShareExpenseSheetState extends State<ShareExpenseSheet> {
  final _phoneCtrl = TextEditingController();
  _SharePeriodMode _mode = _SharePeriodMode.singleDate;
  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _fromYear = DateTime.now().year;
  int _fromMonth = DateTime.now().month;
  int _toYear = DateTime.now().year;
  int _toMonth = DateTime.now().month;
  String? _selectedCategory;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final picked = await ContactPicker.pick();
      if (picked != null && picked.phone.isNotEmpty && mounted) {
        setState(() => _phoneCtrl.text = picked.phone);
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _categoryEmoji(String category) {
    switch (category.trim().toLowerCase()) {
      case 'food':
        return '🍗';
      case 'groceries':
        return '🛒';
      case 'transport':
        return '🚗';
      case 'bills':
        return '🧾';
      case 'shopping':
        return '🛍️';
      case 'health':
        return '💊';
      case 'entertainment':
        return '🎬';
      case 'bank/upi':
      case 'auto':
        return '🏦';
      case 'other':
      default:
        return '📦';
    }
  }

  String _formatSingleDateMessage(DateTime date, List<Expense> list) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final byCat = <String, double>{};
    double total = 0;
    for (final e in list) {
      total += e.amount;
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }

    final lines = <String>['Here are my *$dateStr* expenses:', ''];
    for (final entry in byCat.entries) {
      final emoji = _categoryEmoji(entry.key);
      lines.add('$emoji ${entry.key}: ${currency.format(entry.value)}');
    }
    lines.add('');
    lines.add('*Total Spent: ${currency.format(total)}*');
    return lines.join('\n');
  }

  String _formatPeriodMessage(String titleLabel, List<Expense> list) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    // Group date-wise -> category totals
    final byDate = <String, List<Expense>>{};
    double grandTotal = 0;
    for (final e in list) {
      grandTotal += e.amount;
      final key = DateFormat('yyyy-MM-dd').format(e.expenseDate);
      byDate.putIfAbsent(key, () => []).add(e);
    }

    final sortedDates = byDate.keys.toList()..sort();
    final lines = <String>['Here are my *$titleLabel* expenses:', ''];

    for (final dKey in sortedDates) {
      final items = byDate[dKey]!;
      final dt = DateTime.parse(dKey);
      final label = DateFormat('dd MMM yyyy').format(dt);
      final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);

      final catMap = <String, double>{};
      for (final e in items) {
        catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
      }

      lines.add('📅 *$label* (Total: ${currency.format(dayTotal)})');
      for (final c in catMap.entries) {
        final emoji = _categoryEmoji(c.key);
        lines.add('  $emoji ${c.key}: ${currency.format(c.value)}');
      }
      lines.add('');
    }

    lines.add('*Final Total: ${currency.format(grandTotal)}*');
    return lines.join('\n');
  }

  Future<void> _send() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final DateTime from;
      final DateTime to;
      if (_mode == _SharePeriodMode.customMonth) {
        from = DateTime(_selectedYear, _selectedMonth, 1);
        to = DateTime(_selectedYear, _selectedMonth + 1, 0);
      } else if (_mode == _SharePeriodMode.monthRange) {
        final start = DateTime(_fromYear, _fromMonth, 1);
        final end = DateTime(_toYear, _toMonth + 1, 0);
        if (end.isBefore(start)) {
          from = DateTime(_toYear, _toMonth, 1);
          to = DateTime(_fromYear, _fromMonth + 1, 0);
        } else {
          from = start;
          to = end;
        }
      } else {
        from = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        to = from;
      }

      final res = await ApiClient.instance.fetchExpenses(
        from: from,
        to: to,
        category: _selectedCategory,
      );
      if (res.expenses.isEmpty) {
        if (mounted) {
          setState(() {
            _sending = false;
            _error = 'No expenses found for the selected filter.';
          });
        }
        return;
      }

      String message;
      if (_mode == _SharePeriodMode.singleDate) {
        message = _formatSingleDateMessage(_selectedDate, res.expenses);
      } else if (_mode == _SharePeriodMode.customMonth) {
        final mName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth, 1));
        message = _formatPeriodMessage(mName, res.expenses);
      } else {
        final fName = DateFormat('MMM yyyy').format(from);
        final tName = DateFormat('MMM yyyy').format(to);
        message = _formatPeriodMessage(fName == tName ? fName : '$fName – $tName', res.expenses);
      }

      final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      if (!mounted) return;

      if (rawPhone.length >= 8) {
        final phone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;
        final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final waPickerUri = Uri.parse(
          'whatsapp://send?text=${Uri.encodeComponent(message)}',
        );
        final launchedWa = await launchUrl(
          waPickerUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launchedWa) {
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          final origin = (box != null && box.hasSize && !box.size.isEmpty)
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100);
          await Share.share(message, sharePositionOrigin: origin);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final years = List.generate(11, (i) => 2020 + i);
    final months = List.generate(12, (i) => i + 1);

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
                  Icon(Icons.chat_rounded, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text(
                    'Send Expense to WhatsApp',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number (optional)',
                  hintText: 'Leave blank to pick a WhatsApp Group or Chat',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts_rounded, color: AppTheme.accent),
                    onPressed: _pickContact,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<_SharePeriodMode>(
                segments: const [
                  ButtonSegment(value: _SharePeriodMode.singleDate, label: Text('Date')),
                  ButtonSegment(value: _SharePeriodMode.customMonth, label: Text('Month')),
                  ButtonSegment(value: _SharePeriodMode.monthRange, label: Text('Month–Month')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 14),
              if (_mode == _SharePeriodMode.singleDate)
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                )
              else if (_mode == _SharePeriodMode.customMonth)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedMonth,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Month'),
                        items: months
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  DateFormat('MMMM').format(DateTime(2026, m)),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedMonth = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: years.contains(_selectedYear)
                            ? _selectedYear
                            : years.last,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedYear = v);
                        },
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _fromMonth,
                            dropdownColor: AppTheme.card,
                            decoration: const InputDecoration(labelText: 'From Month'),
                            items: months
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(DateFormat('MMM').format(DateTime(2026, m))),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _fromMonth = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: years.contains(_fromYear) ? _fromYear : years.last,
                            dropdownColor: AppTheme.card,
                            decoration: const InputDecoration(labelText: 'From Year'),
                            items: years
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _fromYear = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _toMonth,
                            dropdownColor: AppTheme.card,
                            decoration: const InputDecoration(labelText: 'To Month'),
                            items: months
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(DateFormat('MMM').format(DateTime(2026, m))),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _toMonth = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: years.contains(_toYear) ? _toYear : years.last,
                            dropdownColor: AppTheme.card,
                            decoration: const InputDecoration(labelText: 'To Year'),
                            items: years
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _toYear = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory ?? '',
                dropdownColor: AppTheme.card,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Categories')),
                  ...kDefaultCategories.map(
                    (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ),
                  const DropdownMenuItem(value: 'Bank/UPI', child: Text('Bank/UPI')),
                ],
                onChanged: (v) => setState(
                  () => _selectedCategory = (v == null || v.isEmpty) ? null : v,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppTheme.danger)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Preparing...' : 'Send to WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF032318),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
