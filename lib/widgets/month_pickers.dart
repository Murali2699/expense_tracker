import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

Future<DateTime?> showSingleMonthPicker(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  int year = (initial ?? now).year;
  int month = (initial ?? now).month;
  final years = List.generate(11, (i) => 2020 + i);
  final months = List.generate(12, (i) => i + 1);

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Select Month'),
        content: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: month,
                dropdownColor: AppTheme.card,
                decoration: const InputDecoration(labelText: 'Month'),
                items: months
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setS(() => month = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: years.contains(year) ? year : years.last,
                dropdownColor: AppTheme.card,
                decoration: const InputDecoration(labelText: 'Year'),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setS(() => year = v);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, DateTime(year, month, 1)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF032318),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

Future<({DateTime from, DateTime to})?> showMonthRangePicker(
  BuildContext context, {
  DateTime? initialFrom,
  DateTime? initialTo,
}) async {
  final now = DateTime.now();
  int fromYear = (initialFrom ?? now).year;
  int fromMonth = (initialFrom ?? now).month;
  int toYear = (initialTo ?? now).year;
  int toMonth = (initialTo ?? now).month;
  final years = List.generate(11, (i) => 2020 + i);
  final months = List.generate(12, (i) => i + 1);

  return showDialog<({DateTime from, DateTime to})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Month to Month'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('From Month', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: fromMonth,
                    dropdownColor: AppTheme.card,
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMM').format(DateTime(2026, m))),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setS(() => fromMonth = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: years.contains(fromYear) ? fromYear : years.last,
                    dropdownColor: AppTheme.card,
                    items: years
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setS(() => fromYear = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('To Month', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: toMonth,
                    dropdownColor: AppTheme.card,
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMM').format(DateTime(2026, m))),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setS(() => toMonth = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: years.contains(toYear) ? toYear : years.last,
                    dropdownColor: AppTheme.card,
                    items: years
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setS(() => toYear = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final start = DateTime(fromYear, fromMonth, 1);
              final end = DateTime(toYear, toMonth + 1, 0);
              if (end.isBefore(start)) {
                Navigator.pop(
                  ctx,
                  (from: DateTime(toYear, toMonth, 1), to: DateTime(fromYear, fromMonth + 1, 0)),
                );
              } else {
                Navigator.pop(ctx, (from: start, to: end));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF032318),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}
