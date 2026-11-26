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
    required this.selectedCategory,
    required this.extraCategories,
    required this.onPresetSelected,
    required this.onPickDateRange,
    required this.onCategorySelected,
  });

  final DateFilterPreset datePreset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String? selectedCategory;
  final List<String> extraCategories;
  final ValueChanged<DateFilterPreset> onPresetSelected;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final allCategories = <String>{
      ...kDefaultCategories.map((c) => c.name),
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
        ? DateFilterPreset.all
        : datePreset;

    String customLabel = 'Custom';
    if (effectivePreset == DateFilterPreset.customRange &&
        customFrom != null &&
        customTo != null) {
      final f = DateFormat('dd MMM').format(customFrom!);
      final t = DateFormat('dd MMM').format(customTo!);
      customLabel = f == t ? f : '$f – $t';
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
            ],
            onChanged: (val) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (val == null) return;
              if (val == DateFilterPreset.customRange) {
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
