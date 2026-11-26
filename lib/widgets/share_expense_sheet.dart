import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/contact_picker.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

class ShareExpenseSheet extends StatefulWidget {
  const ShareExpenseSheet({super.key});

  @override
  State<ShareExpenseSheet> createState() => _ShareExpenseSheetState();
}

class _ShareExpenseSheetState extends State<ShareExpenseSheet> {
  final _phoneCtrl = TextEditingController();
  bool _byMonth = false;
  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
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

  String _formatSingleDateMessage(DateTime date, List<Expense> list) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final byCat = <String, List<Expense>>{};
    double total = 0;
    for (final e in list) {
      total += e.amount;
      byCat.putIfAbsent(e.category, () => []).add(e);
    }

    final lines = <String>['Here are my *$dateStr* expenses:', ''];
    for (final entry in byCat.entries) {
      final catTotal = entry.value.fold<double>(0, (s, e) => s + e.amount);
      final notes = entry.value
          .map((e) => e.note.isNotEmpty ? '${e.note} (${currency.format(e.amount)})' : currency.format(e.amount))
          .join(', ');
      lines.add('• ${entry.key}: ${currency.format(catTotal)} [$notes]');
    }
    lines.add('');
    lines.add('*Total Spent: ${currency.format(total)}*');
    return lines.join('\n');
  }

  String _formatMonthMessage(int year, int month, List<Expense> list) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month, 1));

    // Group date-wise -> category totals
    final byDate = <String, List<Expense>>{};
    double grandTotal = 0;
    for (final e in list) {
      grandTotal += e.amount;
      final key = DateFormat('yyyy-MM-dd').format(e.expenseDate);
      byDate.putIfAbsent(key, () => []).add(e);
    }

    final sortedDates = byDate.keys.toList()..sort();
    final lines = <String>['Here are my *$monthName* expenses:', ''];

    for (final dKey in sortedDates) {
      final items = byDate[dKey]!;
      final dt = DateTime.parse(dKey);
      final label = DateFormat('dd MMM yyyy').format(dt);
      final dayTotal = items.fold<double>(0, (s, e) => s + e.amount);

      final catMap = <String, double>{};
      for (final e in items) {
        catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
      }

      lines.add('$label (Total: ${currency.format(dayTotal)})');
      for (final c in catMap.entries) {
        lines.add('  • ${c.key}: ${currency.format(c.value)}');
      }
      lines.add('');
    }

    lines.add('*Final Month Total: ${currency.format(grandTotal)}*');
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
      if (_byMonth) {
        from = DateTime(_selectedYear, _selectedMonth, 1);
        to = DateTime(_selectedYear, _selectedMonth + 1, 0);
      } else {
        from = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        to = from;
      }

      final res = await ApiClient.instance.fetchExpenses(from: from, to: to);
      if (res.expenses.isEmpty) {
        if (mounted) {
          setState(() {
            _sending = false;
            _error = 'No expenses found for the selected period.';
          });
        }
        return;
      }

      final message = _byMonth
          ? _formatMonthMessage(_selectedYear, _selectedMonth, res.expenses)
          : _formatSingleDateMessage(_selectedDate, res.expenses);

      final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      if (!mounted) return;

      if (rawPhone.length >= 8) {
        final phone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;
        final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final box = context.findRenderObject() as RenderBox?;
        final origin = (box != null && box.hasSize && !box.size.isEmpty)
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100);
        await Share.share(message, sharePositionOrigin: origin);
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Single Date')),
                  ButtonSegment(value: true, label: Text('Full Month')),
                ],
                selected: {_byMonth},
                onSelectionChanged: (s) => setState(() => _byMonth = s.first),
              ),
              const SizedBox(height: 14),
              if (!_byMonth)
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                )
              else
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
