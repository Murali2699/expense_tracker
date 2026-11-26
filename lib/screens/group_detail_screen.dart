import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/group_share_sheet.dart';
import '../widgets/month_pickers.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final ExpenseGroup group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  DateFilterPreset _datePreset = DateFilterPreset.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _customFrom;
  DateTime? _customTo;
  String? _selectedCategory;

  List<GroupExpense> _expenses = [];
  double _totalAmount = 0;
  List<GroupUserSummary> _byUser = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime? from, DateTime? to}) _computeRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case DateFilterPreset.today:
        return (from: today, to: today);
      case DateFilterPreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: y);
      case DateFilterPreset.customMonth:
      case DateFilterPreset.selectedMonth:
      case DateFilterPreset.thisMonth:
        return (
          from: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
          to: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
        );
      case DateFilterPreset.customRange:
      case DateFilterPreset.monthRange:
        return (from: _customFrom, to: _customTo);
      case DateFilterPreset.all:
        return (from: null, to: null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _computeRange();
      final res = await ApiClient.instance.fetchGroupExpenses(
        groupId: widget.group.id,
        from: range.from,
        to: range.to,
        category: _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _expenses = res.expenses;
          _totalAmount = res.totalAmount;
          _byUser = res.byUser;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _inviteDialog() async {
    final userCtrl = TextEditingController();
    UserLookup? found;
    String? err;
    bool searching = false;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Invite User to Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Login username',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: searching
                        ? null
                        : () async {
                            final q = userCtrl.text.trim();
                            if (q.isEmpty) return;
                            setS(() {
                              searching = true;
                              err = null;
                              found = null;
                            });
                            try {
                              final u = await ApiClient.instance.lookupUser(q);
                              setS(() => found = u);
                            } catch (e) {
                              setS(() => err = e.toString());
                            } finally {
                              setS(() => searching = false);
                            }
                          },
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF032318),
                    ),
                    icon: searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ],
              if (found != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Username: ${found!.username}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        found!.phoneNumber.isNotEmpty
                            ? 'Contact: ${found!.phoneNumber}'
                            : 'Contact: Not set',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (found != null)
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        setS(() => sending = true);
                        try {
                          await ApiClient.instance.inviteToGroup(
                            groupId: widget.group.id,
                            username: found!.username,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Request sent to @${found!.username}!')),
                            );
                          }
                        } catch (e) {
                          setS(() {
                            sending = false;
                            err = e.toString();
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF032318),
                ),
                child: const Text('Send Request'),
              ),
          ],
        ),
      ),
    );
    userCtrl.dispose();
  }

  Future<void> _addExpenseSheet() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final customCatCtrl = TextEditingController();
    String category = kDefaultCategories.first.name;
    DateTime selectedDate = DateTime.now();
    bool saving = false;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Post Expense to ${widget.group.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: AppTheme.card,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        ...kDefaultCategories.map(
                          (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                        ),
                        const DropdownMenuItem(value: 'Bank/UPI', child: Text('Bank/UPI')),
                      ],
                      onChanged: (v) {
                        if (v != null) setS(() => category = v);
                      },
                    ),
                    if (category == 'Other') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customCatCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Custom Category (optional)',
                          hintText: 'e.g. Soap, Water',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setS(() => selectedDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final amt = double.tryParse(amountCtrl.text.trim());
                              if (amt == null || amt <= 0) return;
                              setS(() => saving = true);
                              final finalCat = (category == 'Other' &&
                                      customCatCtrl.text.trim().isNotEmpty)
                                  ? customCatCtrl.text.trim()
                                  : category;
                              try {
                                await ApiClient.instance.addGroupExpense(
                                  groupId: widget.group.id,
                                  expenseDate: selectedDate,
                                  category: finalCat,
                                  amount: amt,
                                  note: noteCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setS(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF032318),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(saving ? 'Saving...' : 'Post to Group'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    amountCtrl.dispose();
    noteCtrl.dispose();
    customCatCtrl.dispose();
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final extraCats = <String>{
      for (final u in _byUser) ...u.byCategory.keys,
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            tooltip: 'Invite User',
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accent),
            onPressed: _inviteDialog,
          ),
          IconButton(
            tooltip: 'Share to WhatsApp',
            icon: const Icon(Icons.share_rounded, color: AppTheme.accent),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => GroupShareSheet(group: widget.group),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpenseSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                    'Group Total',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(_totalAmount),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  if (_byUser.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _byUser
                          .map(
                            (u) => Chip(
                              backgroundColor: AppTheme.surface,
                              side: const BorderSide(color: AppTheme.border),
                              label: Text(
                                '${u.username}: ${currency.format(u.totalAmount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilterBar(
              datePreset: _datePreset,
              customFrom: _customFrom,
              customTo: _customTo,
              selectedMonth: _selectedMonth,
              selectedCategory: _selectedCategory,
              extraCategories: extraCats,
              onPresetSelected: (p) {
                setState(() => _datePreset = p);
                _load();
              },
              onPickDateRange: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customFrom ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _datePreset = DateFilterPreset.customRange;
                    _customFrom = picked;
                    _customTo = picked;
                  });
                  _load();
                }
              },
              onPickCustomMonth: () async {
                final m = await showSingleMonthPicker(
                  context,
                  initial: _selectedMonth,
                );
                if (m != null) {
                  setState(() {
                    _datePreset = DateFilterPreset.customMonth;
                    _selectedMonth = m;
                  });
                  _load();
                }
              },
              onPickMonthRange: () async {
                final range = await showMonthRangePicker(
                  context,
                  initialFrom: _customFrom,
                  initialTo: _customTo,
                );
                if (range != null) {
                  setState(() {
                    _datePreset = DateFilterPreset.monthRange;
                    _customFrom = range.from;
                    _customTo = range.to;
                  });
                  _load();
                }
              },
              onCategorySelected: (cat) {
                setState(() => _selectedCategory = cat);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.danger))
            else if (_expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No group expenses for this filter.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ..._expenses.map((item) {
                final meta = categoryMetaFor(item.category);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: meta.color.withValues(alpha: 0.16),
                        child: Icon(meta.icon, color: meta.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.category} • @${item.username}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('dd MMM yyyy').format(item.expenseDate)}'
                              '${item.note.isNotEmpty ? ' • ${item.note}' : ''}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currency.format(item.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
