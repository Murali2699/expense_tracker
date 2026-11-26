import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/contact_picker.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

enum _GroupShareMode { singleDate, customMonth, monthRange }

class GroupShareSheet extends StatefulWidget {
  const GroupShareSheet({super.key, required this.group});

  final ExpenseGroup group;

  @override
  State<GroupShareSheet> createState() => _GroupShareSheetState();
}

class _GroupShareSheetState extends State<GroupShareSheet> {
  final _phoneCtrl = TextEditingController();
  _GroupShareMode _mode = _GroupShareMode.singleDate;
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

  Future<void> _send() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final DateTime from;
      final DateTime to;
      final String periodLabel;
      if (_mode == _GroupShareMode.customMonth) {
        from = DateTime(_selectedYear, _selectedMonth, 1);
        to = DateTime(_selectedYear, _selectedMonth + 1, 0);
        periodLabel = DateFormat('MMMM yyyy').format(from);
      } else if (_mode == _GroupShareMode.monthRange) {
        final s = DateTime(_fromYear, _fromMonth, 1);
        final e = DateTime(_toYear, _toMonth + 1, 0);
        from = e.isBefore(s) ? DateTime(_toYear, _toMonth, 1) : s;
        to = e.isBefore(s) ? DateTime(_fromYear, _fromMonth + 1, 0) : e;
        final fStr = DateFormat('MMM yyyy').format(from);
        final tStr = DateFormat('MMM yyyy').format(to);
        periodLabel = fStr == tStr ? fStr : '$fStr – $tStr';
      } else {
        from = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        to = from;
        periodLabel = DateFormat('dd MMM yyyy').format(from);
      }

      final res = await ApiClient.instance.fetchGroupExpenses(
        groupId: widget.group.id,
        from: from,
        to: to,
        category: _selectedCategory,
      );

      if (res.expenses.isEmpty) {
        if (mounted) {
          setState(() {
            _sending = false;
            _error = 'No group expenses found for this filter.';
          });
        }
        return;
      }

      final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
      final lines = <String>[
        '*${widget.group.name}* expenses ($periodLabel):',
        '',
      ];

      for (final u in res.byUser) {
        lines.add('*${u.username}* - Total: ${currency.format(u.totalAmount)}');
        for (final c in u.byCategory.entries) {
          lines.add('  • ${c.key}: ${currency.format(c.value)}');
        }
        lines.add('');
      }
      lines.add('*Group Total: ${currency.format(res.totalAmount)}*');

      final message = lines.join('\n');
      final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      if (!mounted) return;

      if (rawPhone.length >= 8) {
        final phone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;
        final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final waUri = Uri.parse(
          'whatsapp://send?text=${Uri.encodeComponent(message)}',
        );
        final ok = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
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
              Row(
                children: [
                  const Icon(Icons.chat_rounded, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share "${widget.group.name}" to WhatsApp',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
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
              SegmentedButton<_GroupShareMode>(
                segments: const [
                  ButtonSegment(value: _GroupShareMode.singleDate, label: Text('Date')),
                  ButtonSegment(value: _GroupShareMode.customMonth, label: Text('Month')),
                  ButtonSegment(value: _GroupShareMode.monthRange, label: Text('Month–Month')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 14),
              if (_mode == _GroupShareMode.singleDate)
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                )
              else if (_mode == _GroupShareMode.customMonth)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedMonth,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Month'),
                        items: months
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedMonth = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: years.contains(_selectedYear) ? _selectedYear : years.last,
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
                label: Text(_sending ? 'Preparing...' : 'Send Group Summary'),
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
