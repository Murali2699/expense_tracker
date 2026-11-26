import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';

enum _CalcPeriod { today, yesterday, customDate, customMonth, monthRange, all }

class CalculateExpenseSheet extends StatefulWidget {
  const CalculateExpenseSheet({
    super.key,
    this.initialGroupMode = false,
    this.initialGroupId,
  });

  final bool initialGroupMode;
  final String? initialGroupId;

  @override
  State<CalculateExpenseSheet> createState() => _CalculateExpenseSheetState();
}

class _CalculateExpenseSheetState extends State<CalculateExpenseSheet> {
  late bool _isGroupMode;
  _CalcPeriod _period = _CalcPeriod.today;
  DateTime _customDate = DateTime.now();
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int _fromMonth = DateTime.now().month;
  int _fromYear = DateTime.now().year;
  int _toMonth = DateTime.now().month;
  int _toYear = DateTime.now().year;
  String? _category;

  List<ExpenseGroup> _groups = [];
  String? _selectedGroupId;
  bool _loadingGroups = false;

  bool _loading = false;
  String? _error;
  ExpenseSummary? _summary;
  int _entryCount = 0;
  double _groupTotal = 0;
  List<GroupUserSummary> _groupByUser = [];
  String _rangeLabel = 'Today';

  @override
  void initState() {
    super.initState();
    _isGroupMode = widget.initialGroupMode;
    _selectedGroupId = widget.initialGroupId;
    if (_isGroupMode) {
      _loadGroups();
    } else {
      _calculate();
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final res = await ApiClient.instance.fetchGroups();
      if (mounted) {
        setState(() {
          _groups = res.groups;
          if (_selectedGroupId == null ||
              !_groups.any((g) => g.id == _selectedGroupId)) {
            _selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
          }
        });
        if (_selectedGroupId != null) {
          _calculate();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  ({DateTime? from, DateTime? to, String label}) _computePeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_period) {
      case _CalcPeriod.today:
        return (
          from: today,
          to: today,
          label: 'Today (${DateFormat('dd MMM yyyy').format(today)})',
        );
      case _CalcPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (
          from: y,
          to: y,
          label: 'Yesterday (${DateFormat('dd MMM yyyy').format(y)})',
        );
      case _CalcPeriod.customDate:
        final d = DateTime(_customDate.year, _customDate.month, _customDate.day);
        return (
          from: d,
          to: d,
          label: DateFormat('dd MMM yyyy').format(d),
        );
      case _CalcPeriod.customMonth:
        final s = DateTime(_year, _month, 1);
        final e = DateTime(_year, _month + 1, 0);
        return (from: s, to: e, label: DateFormat('MMMM yyyy').format(s));
      case _CalcPeriod.monthRange:
        final s = DateTime(_fromYear, _fromMonth, 1);
        final e = DateTime(_toYear, _toMonth + 1, 0);
        final from = e.isBefore(s) ? DateTime(_toYear, _toMonth, 1) : s;
        final to = e.isBefore(s) ? DateTime(_fromYear, _fromMonth + 1, 0) : e;
        final fStr = DateFormat('MMM yyyy').format(from);
        final tStr = DateFormat('MMM yyyy').format(to);
        return (from: from, to: to, label: fStr == tStr ? fStr : '$fStr – $tStr');
      case _CalcPeriod.all:
        return (from: null, to: null, label: 'All Time');
    }
  }

  Future<void> _calculate() async {
    if (_isGroupMode && _selectedGroupId == null) {
      setState(() {
        _error = 'No group selected.';
        _groupByUser = [];
        _groupTotal = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final p = _computePeriod();

    try {
      if (_isGroupMode) {
        final res = await ApiClient.instance.fetchGroupExpenses(
          groupId: _selectedGroupId!,
          from: p.from,
          to: p.to,
          category: _category,
        );
        if (mounted) {
          setState(() {
            _groupTotal = res.totalAmount;
            _groupByUser = res.byUser;
            _entryCount = res.expenses.length;
            _rangeLabel = p.label;
          });
        }
      } else {
        final res = await ApiClient.instance.fetchExpenses(
          from: p.from,
          to: p.to,
          category: _category,
        );
        if (mounted) {
          setState(() {
            _summary = res.summary;
            _entryCount = res.expenses.length;
            _rangeLabel = p.label;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final years = List.generate(11, (i) => 2020 + i);
    final months = List.generate(12, (i) => i + 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_rounded, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text(
                    'Calculate Expenses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Personal')),
                  ButtonSegment(value: true, label: Text('Group')),
                ],
                selected: {_isGroupMode},
                onSelectionChanged: (s) {
                  final next = s.first;
                  setState(() {
                    _isGroupMode = next;
                    _error = null;
                  });
                  if (next && _groups.isEmpty) {
                    _loadGroups();
                  } else {
                    _calculate();
                  }
                },
              ),
              if (_isGroupMode) ...[
                const SizedBox(height: 12),
                if (_loadingGroups)
                  const LinearProgressIndicator(color: AppTheme.accent)
                else if (_groups.isEmpty)
                  const Text(
                    'No groups available. Create or join a group first.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGroupId,
                    dropdownColor: AppTheme.card,
                    decoration: const InputDecoration(labelText: 'Select Group'),
                    items: _groups
                        .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedGroupId = v);
                      _calculate();
                    },
                  ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Today', _CalcPeriod.today),
                  _chip('Yesterday', _CalcPeriod.yesterday),
                  _chip('Custom Date', _CalcPeriod.customDate),
                  _chip('Custom Month', _CalcPeriod.customMonth),
                  _chip('Month–Month', _CalcPeriod.monthRange),
                  _chip('All', _CalcPeriod.all),
                ],
              ),
              if (_period == _CalcPeriod.customDate) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _customDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _customDate = picked);
                      _calculate();
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('dd MMM yyyy').format(_customDate)),
                ),
              ] else if (_period == _CalcPeriod.customMonth) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _month,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Month'),
                        items: months
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _month = v);
                            _calculate();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: years.contains(_year) ? _year : years.last,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _year = v);
                            _calculate();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ] else if (_period == _CalcPeriod.monthRange) ...[
                const SizedBox(height: 12),
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
                          if (v != null) {
                            setState(() => _fromMonth = v);
                            _calculate();
                          }
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
                          if (v != null) {
                            setState(() => _fromYear = v);
                            _calculate();
                          }
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
                          if (v != null) {
                            setState(() => _toMonth = v);
                            _calculate();
                          }
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
                          if (v != null) {
                            setState(() => _toYear = v);
                            _calculate();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category ?? '',
                dropdownColor: AppTheme.card,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Categories')),
                  ...kDefaultCategories.map(
                    (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ),
                  const DropdownMenuItem(value: 'Bank/UPI', child: Text('Bank/UPI')),
                ],
                onChanged: (v) {
                  setState(() => _category = (v == null || v.isEmpty) ? null : v);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _calculate,
                icon: const Icon(Icons.calculate_rounded, size: 18),
                label: const Text('Calculate'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF032318),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E4D3E)),
                ),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      )
                    : _error != null
                        ? Text(_error!, style: const TextStyle(color: AppTheme.danger))
                        : _isGroupMode
                            ? _buildGroupResult(currency)
                            : _buildPersonalResult(currency),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupResult(NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _rangeLabel,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$_entryCount ${_entryCount == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          currency.format(_groupTotal),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        if (_groupByUser.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'No expenses in this group for this filter.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          ..._groupByUser.map((u) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@${u.username}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        currency.format(u.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  if (u.byCategory.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: u.byCategory.entries
                          .map((c) => Text(
                                '• ${c.key}: ${currency.format(c.value)}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPersonalResult(NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _rangeLabel,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$_entryCount ${_entryCount == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          currency.format(_summary?.totalAmount ?? 0),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        if (_summary != null && _summary!.byCategory.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._summary!.byCategory.map((c) {
            final meta = categoryMetaFor(c.category);
            final pct = _summary!.totalAmount > 0
                ? (c.totalAmount / _summary!.totalAmount) * 100
                : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(meta.icon, color: meta.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c.category, style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    currency.format(c.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _chip(String label, _CalcPeriod period) {
    final selected = _period == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.accent.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppTheme.accent : AppTheme.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppTheme.accent : AppTheme.border),
      onSelected: (_) {
        setState(() => _period = period);
        _calculate();
      },
    );
  }
}
