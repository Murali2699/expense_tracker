import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/biometric_service.dart';
import '../core/secure_storage.dart';
import '../models/expense.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_bottom_nav.dart';
import '../widgets/expense_tile.dart';
import '../widgets/filter_bar.dart';
import '../widgets/summary_card.dart';
import 'add_expense_screen.dart';
import 'auto_expenses_screen.dart';
import 'borrowed_screen.dart';
import 'completed_screen.dart';
import 'expense_detail_screen.dart';
import 'lent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.biometricEnabled,
    required this.biometricAvailable,
    required this.biometricLabel,
    required this.onToggleBiometric,
    required this.onLogout,
  });

  final bool biometricEnabled;
  final bool biometricAvailable;
  final String biometricLabel;
  final Future<void> Function(bool enable) onToggleBiometric;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ExpenseController _controller = ExpenseController();
  int _navIndex = 0;

  static const _titles = [
    'Expenses',
    'Auto Expense',
    'Money Given',
    'I Bought',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _controller.loadExpenses();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskBiometric());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeAskBiometric() async {
    final storage = SecureStorageService.instance;
    final alreadyPrompted = await storage.wasBiometricPrompted();
    if (alreadyPrompted || !widget.biometricAvailable || !mounted) return;

    await storage.setBiometricPrompted();
    if (!mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Enable ${widget.biometricLabel}?'),
        content: Text(
          'Protect your expense records with ${widget.biometricLabel} whenever you open the app. '
          'You can also enable or disable this anytime by long-pressing the app icon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF032318),
            ),
            child: Text('Enable ${widget.biometricLabel}'),
          ),
        ],
      ),
    );

    if (enable == true) {
      final verified = await BiometricService.instance.authenticate(
        reason: 'Confirm ${widget.biometricLabel} to enable app lock',
      );
      if (verified) {
        await widget.onToggleBiometric(true);
      }
    }
  }

  Future<void> _pickMonth() async {
    int year = _controller.selectedMonth.year;
    final years = List.generate(11, (i) => 2020 + i);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Year & Month',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    DropdownButton<int>(
                      value: years.contains(year) ? year : years.last,
                      dropdownColor: AppTheme.surface,
                      items: years
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (y) {
                        if (y != null) setModalState(() => year = y);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = DateTime(year, i + 1, 1);
                    return ActionChip(
                      label: Text(DateFormat('MMM').format(m)),
                      backgroundColor: AppTheme.surface,
                      side: const BorderSide(color: AppTheme.border),
                      onPressed: () => Navigator.pop(ctx, m),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked != null) {
      await _controller.setDatePreset(
        DateFilterPreset.selectedMonth,
        month: picked,
      );
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: _controller.customFrom != null && _controller.customTo != null
          ? DateTimeRange(start: _controller.customFrom!, end: _controller.customTo!)
          : DateTimeRange(start: now, end: now),
    );
    if (picked != null) {
      await _controller.setCustomDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_navIndex]),
        actions: [
          if (widget.biometricAvailable)
            IconButton(
              tooltip: widget.biometricEnabled
                  ? 'Disable ${widget.biometricLabel}'
                  : 'Enable ${widget.biometricLabel}',
              icon: Icon(
                widget.biometricEnabled
                    ? Icons.verified_user_rounded
                    : Icons.shield_outlined,
                color: widget.biometricEnabled
                    ? AppTheme.accent
                    : AppTheme.textMuted,
              ),
              onPressed: () async {
                final target = !widget.biometricEnabled;
                final verified = await BiometricService.instance.authenticate(
                  reason: target
                      ? 'Authenticate to enable ${widget.biometricLabel}'
                      : 'Authenticate to disable ${widget.biometricLabel}',
                );
                if (verified) {
                  await widget.onToggleBiometric(target);
                }
              },
            ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(controller: _controller),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: AdaptiveBottomNav(
        selectedIndex: _navIndex,
        onSelected: (i) => setState(() => _navIndex = i),
        items: const [
          NavItemData(label: 'Expenses', icon: Icons.receipt_long_rounded),
          NavItemData(label: 'Auto', icon: Icons.auto_awesome_rounded),
          NavItemData(label: 'I Gave', icon: Icons.call_made_rounded),
          NavItemData(label: 'I Bought', icon: Icons.call_received_rounded),
          NavItemData(label: 'Done', icon: Icons.history_rounded),
        ],
      ),
      body: SafeArea(
        child: switch (_navIndex) {
          0 => _buildExpensesTab(),
          1 => AutoExpensesScreen(controller: _controller),
          2 => const LentScreen(),
          3 => const BorrowedScreen(),
          _ => const CompletedScreen(),
        },
      ),
    );
  }

  Widget _buildExpensesTab() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: _controller.loadExpenses,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              SummaryCard(
                title: _controller.periodTitle,
                summary: _controller.summary,
                selectedCategory: _controller.selectedCategory,
                onCategoryTap: _controller.setCategoryFilter,
              ),
              const SizedBox(height: 16),
              FilterBar(
                datePreset: _controller.datePreset,
                selectedMonth: _controller.selectedMonth,
                selectedCategory: _controller.selectedCategory,
                onPresetSelected: (p) => _controller.setDatePreset(p),
                onPickMonth: _pickMonth,
                onPickDateRange: _pickDateRange,
                onCategorySelected: _controller.setCategoryFilter,
              ),
              const SizedBox(height: 18),
              if (_controller.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_controller.error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.danger),
                  ),
                  child: Text(
                    _controller.error!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                )
              else if (_controller.expenses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 20,
                  ),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: AppTheme.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No expenses for this filter',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._controller.expenses.map(
                  (expense) => ExpenseTile(
                    expense: expense,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExpenseDetailScreen(
                          expense: expense,
                          controller: _controller,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
