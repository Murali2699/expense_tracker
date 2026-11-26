import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.datePreset,
    required this.customFrom,
    required this.customTo,
    this.selectedMonth,
    required this.selectedCategory,
    required this.extraCategories,
    required this.onPresetSelected,
    required this.onPickDateRange,
    this.onPickCustomMonth,
    this.onPickMonthRange,
    required this.onCategorySelected,
  });

  final DateFilterPreset datePreset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final DateTime? selectedMonth;
  final String? selectedCategory;
  final List<String> extraCategories;
  final ValueChanged<DateFilterPreset> onPresetSelected;
  final VoidCallback onPickDateRange;
  final VoidCallback? onPickCustomMonth;
  final VoidCallback? onPickMonthRange;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final allCategories = <String>{
      ...kDefaultCategories.map((c) => c.name),
      'Bank/UPI',
      ...extraCategories.where((c) => c.trim().isNotEmpty),
    }.toList();

    final currentCategory = (selectedCategory != null &&
            allCategories.any(
              (c) => c.toLowerCase() == selectedCategory!.toLowerCase(),
            ))
        ? allCategories.firstWhere(
            (c) => c.toLowerCase() == selectedCategory!.toLowerCase(),
          )
        : '';

    final effectivePreset = (datePreset == DateFilterPreset.thisMonth ||
            datePreset == DateFilterPreset.selectedMonth)
        ? DateFilterPreset.customMonth
        : datePreset;

    String customLabel = 'Custom Date';
    if (effectivePreset == DateFilterPreset.customRange &&
        customFrom != null &&
        customTo != null) {
      final f = DateFormat('dd MMM').format(customFrom!);
      final t = DateFormat('dd MMM').format(customTo!);
      customLabel = f == t ? f : '$f – $t';
    }

    String monthLabel = 'Custom Month';
    if (effectivePreset == DateFilterPreset.customMonth &&
        selectedMonth != null) {
      monthLabel = DateFormat('MMM yyyy').format(selectedMonth!);
    }

    String monthRangeLabel = 'Month to Month';
    if (effectivePreset == DateFilterPreset.monthRange &&
        customFrom != null &&
        customTo != null) {
      final f = DateFormat('MMM yy').format(customFrom!);
      final t = DateFormat('MMM yy').format(customTo!);
      monthRangeLabel = '$f – $t';
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<DateFilterPreset>(
            initialValue: effectivePreset,
            isExpanded: true,
            menuMaxHeight: 320,
            dropdownColor: AppTheme.card,
            decoration: const InputDecoration(
              labelText: 'Date',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            items: [
              const DropdownMenuItem(
                value: DateFilterPreset.all,
                child: Text('All', overflow: TextOverflow.ellipsis),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.today,
                child: Text('Today', overflow: TextOverflow.ellipsis),
              ),
              const DropdownMenuItem(
                value: DateFilterPreset.yesterday,
                child: Text('Yesterday', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: DateFilterPreset.customRange,
                child: Text(customLabel, overflow: TextOverflow.ellipsis),
              ),
              if (onPickCustomMonth != null)
                DropdownMenuItem(
                  value: DateFilterPreset.customMonth,
                  child: Text(monthLabel, overflow: TextOverflow.ellipsis),
                ),
              if (onPickMonthRange != null)
                DropdownMenuItem(
                  value: DateFilterPreset.monthRange,
                  child: Text(monthRangeLabel, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (val) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (val == null) return;
              if (val == DateFilterPreset.customRange) {
                onPickDateRange();
              } else if (val == DateFilterPreset.customMonth &&
                  onPickCustomMonth != null) {
                onPickCustomMonth!();
              } else if (val == DateFilterPreset.monthRange &&
                  onPickMonthRange != null) {
                onPickMonthRange!();
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
            menuMaxHeight: 320,
            dropdownColor: AppTheme.card,
            decoration: const InputDecoration(
              labelText: 'Category',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
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
              FocusManager.instance.primaryFocus?.unfocus();
              onCategorySelected(val == null || val.isEmpty ? null : val);
            },
          ),
        ),
      ],
    );
  }
}
