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
    required this.extraCategories,
    required this.onPresetSelected,
    required this.onPickMonth,
    required this.onPickDateRange,
    required this.onCategorySelected,
  });

  final DateFilterPreset datePreset;
  final DateTime selectedMonth;
  final String? selectedCategory;
  final List<String> extraCategories;
  final ValueChanged<DateFilterPreset> onPresetSelected;
  final VoidCallback onPickMonth;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final allCategories = <String>{
      ...kDefaultCategories.map((c) => c.name),
      ...extraCategories.where((c) => c.trim().isNotEmpty),
    }.toList();

    final currentCategory = (selectedCategory != null &&
            allCategories.any((c) => c.toLowerCase() == selectedCategory!.toLowerCase()))
        ? allCategories.firstWhere(
            (c) => c.toLowerCase() == selectedCategory!.toLowerCase(),
          )
        : '';

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<DateFilterPreset>(
            initialValue: datePreset,
            isExpanded: true,
            dropdownColor: AppTheme.card,
            decoration: const InputDecoration(
              labelText: 'Date Filter',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(
                value: DateFilterPreset.today,
                child: Text('Today', overflow: TextOverflow.ellipsis),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.yesterday,
                child: Text('Yesterday', overflow: TextOverflow.ellipsis),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.thisMonth,
                child: Text('This Month', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: DateFilterPreset.selectedMonth,
                child: Text(
                  datePreset == DateFilterPreset.selectedMonth
                      ? DateFormat('MMM yyyy').format(selectedMonth)
                      : 'Month / Year...',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.customRange,
                child: Text('Calendar...', overflow: TextOverflow.ellipsis),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.all,
                child: Text('All Time', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: (val) {
              if (val == null) return;
              if (val == DateFilterPreset.selectedMonth) {
                onPickMonth();
              } else if (val == DateFilterPreset.customRange) {
                onPickDateRange();
              } else {
                onPresetSelected(val);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: currentCategory,
            isExpanded: true,
            dropdownColor: AppTheme.card,
            decoration: const InputDecoration(
              labelText: 'Category',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All Categories', overflow: TextOverflow.ellipsis),
              ),
              ...allCategories.map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (val) {
              onCategorySelected(val == null || val.isEmpty ? null : val);
            },
          ),
        ),
      ],
    );
  }
}
