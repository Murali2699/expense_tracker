import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/biometric_service.dart';
import '../core/secure_storage.dart';
import '../providers/expense_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_bottom_nav.dart';
import '../widgets/bulk_upload_sheet.dart';
import '../widgets/calculate_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/filter_bar.dart';
import '../widgets/month_pickers.dart';
import '../widgets/share_expense_sheet.dart';
import '../widgets/summary_card.dart';
import 'add_expense_screen.dart';
import 'auto_expenses_screen.dart';
import 'borrowed_screen.dart';
import 'completed_screen.dart';
import 'expense_detail_screen.dart';
import 'groups_screen.dart';
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
  int _pendingGroupRequests = 0;

  static const _titles = [
    'Expenses',
    'Auto Expense',
    'Bulk Upload',
    'Money Given',
    'I Bought',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _controller.loadExpenses();
    _loadGroupBadge();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskBiometric());
  }

  Future<void> _loadGroupBadge() async {
    try {
      final res = await ApiClient.instance.fetchGroups();
      if (mounted) {
        setState(() => _pendingGroupRequests = res.pendingRequests.length);
      }
    } catch (_) {}
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

  Future<void> _pickDateRange() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.customFrom ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      await _controller.setCustomDateRange(picked, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        title: Text(_titles[_navIndex]),
        actions: [
          if (_navIndex == 0)
            _appBarAction(
              icon: Icons.calculate_rounded,
              label: 'Calculate',
              color: AppTheme.accent,
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => const CalculateExpenseSheet(),
                );
              },
            ),
          if (_navIndex == 0)
            _appBarAction(
              icon: Icons.share_rounded,
              label: 'Share',
              color: AppTheme.accent,
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => const ShareExpenseSheet(),
                );
              },
            ),
          _appBarAction(
            icon: _pendingGroupRequests > 0
                ? Icons.notifications_active_rounded
                : Icons.groups_rounded,
            label: _pendingGroupRequests > 0
                ? 'Groups ($_pendingGroupRequests)'
                : 'Groups',
            color: _pendingGroupRequests > 0
                ? Colors.amberAccent
                : AppTheme.accent,
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              );
              _loadGroupBadge();
            },
          ),
          if (widget.biometricAvailable)
            _appBarAction(
              icon: widget.biometricEnabled
                  ? Icons.verified_user_rounded
                  : Icons.shield_outlined,
              label: widget.biometricLabel,
              color: widget.biometricEnabled
                  ? AppTheme.accent
                  : AppTheme.textMuted,
              onTap: () async {
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
          _appBarAction(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: AppTheme.textMuted,
            onTap: widget.onLogout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'addFab',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddExpenseScreen(controller: _controller),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Expense',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: AdaptiveBottomNav(
        selectedIndex: _navIndex,
        onSelected: (i) async {
          FocusManager.instance.primaryFocus?.unfocus();
          if (i == 2) {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppTheme.card,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => BulkUploadSheet(controller: _controller),
            );
            if (mounted) FocusManager.instance.primaryFocus?.unfocus();
            return;
          }
          setState(() => _navIndex = i);
        },
        items: const [
          NavItemData(label: 'Expenses', icon: Icons.receipt_long_rounded),
          NavItemData(label: 'Auto', icon: Icons.auto_awesome_rounded),
          NavItemData(label: 'Bulk', icon: Icons.playlist_add_rounded),
          NavItemData(label: 'I Gave', icon: Icons.call_made_rounded),
          NavItemData(label: 'I Bought', icon: Icons.call_received_rounded),
          NavItemData(label: 'Done', icon: Icons.history_rounded),
        ],
      ),
      body: SafeArea(
        child: switch (_navIndex) {
          0 => _buildExpensesTab(),
          1 => AutoExpensesScreen(controller: _controller),
          3 => const LentScreen(),
          4 => const BorrowedScreen(),
          _ => const CompletedScreen(),
        },
      ),
    );
  }

  Widget _appBarAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                customFrom: _controller.customFrom,
                customTo: _controller.customTo,
                selectedMonth: _controller.selectedMonth,
                selectedCategory: _controller.selectedCategory,
                extraCategories: _controller.summary.byCategory
                    .map((e) => e.category)
                    .toList(),
                onPresetSelected: (p) => _controller.setDatePreset(p),
                onPickDateRange: _pickDateRange,
                onPickCustomMonth: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final m = await showSingleMonthPicker(
                    context,
                    initial: _controller.selectedMonth,
                  );
                  if (m != null) {
                    await _controller.setCustomMonth(m);
                  }
                },
                onPickMonthRange: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final range = await showMonthRangePicker(
                    context,
                    initialFrom: _controller.customFrom,
                    initialTo: _controller.customTo,
                  );
                  if (range != null) {
                    await _controller.setMonthRange(range.from, range.to);
                  }
                },
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
