import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.datePreset,
    required this.selectedMonth,
    required this.selectedCategory,
    required this.onPresetSelected,
    required this.onPickMonth,
    required this.onPickDateRange,
    required this.onCategorySelected,
  });

  final DateFilterPreset datePreset;
  final DateTime selectedMonth;
  final String? selectedCategory;
  final ValueChanged<DateFilterPreset> onPresetSelected;
  final VoidCallback onPickMonth;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                label: 'Today',
                selected: datePreset == DateFilterPreset.today,
                onTap: () => onPresetSelected(DateFilterPreset.today),
              ),
              const SizedBox(width: 8),
              _chip(
                label: 'Yesterday',
                selected: datePreset == DateFilterPreset.yesterday,
                onTap: () => onPresetSelected(DateFilterPreset.yesterday),
              ),
              const SizedBox(width: 8),
              _chip(
                label: 'This Month',
                selected: datePreset == DateFilterPreset.thisMonth,
                onTap: () => onPresetSelected(DateFilterPreset.thisMonth),
              ),
              const SizedBox(width: 8),
              _chip(
                label: datePreset == DateFilterPreset.selectedMonth
                    ? DateFormat('MMM yyyy').format(selectedMonth)
                    : 'Month / Year',
                icon: Icons.calendar_month_rounded,
                selected: datePreset == DateFilterPreset.selectedMonth,
                onTap: onPickMonth,
              ),
              const SizedBox(width: 8),
              _chip(
                label: 'Calendar',
                icon: Icons.date_range_rounded,
                selected: datePreset == DateFilterPreset.customRange,
                onTap: onPickDateRange,
              ),
              const SizedBox(width: 8),
              _chip(
                label: 'All',
                selected: datePreset == DateFilterPreset.all,
                onTap: () => onPresetSelected(DateFilterPreset.all),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                label: 'All Categories',
                selected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              ...kDefaultCategories.map((cat) {
                final isSelected =
                    selectedCategory?.toLowerCase() == cat.name.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _chip(
                    label: cat.name,
                    icon: cat.icon,
                    iconColor: cat.color,
                    selected: isSelected,
                    onTap: () =>
                        onCategorySelected(isSelected ? null : cat.name),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? AppTheme.accent : (iconColor ?? AppTheme.textMuted),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
