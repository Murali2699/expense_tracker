import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.summary,
    required this.selectedCategory,
    required this.onCategoryTap,
  });

  final String title;
  final ExpenseSummary summary;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF112A24), Color(0xFF131A22)],
        ),
        border: Border.all(color: const Color(0xFF1E4D3E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCategory == null ? title : '$title • $selectedCategory',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.count} ${summary.count == 1 ? 'entry' : 'entries'}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currency.format(summary.totalAmount),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          if (summary.byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: summary.byCategory.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = summary.byCategory[index];
                  final meta = categoryMetaFor(item.category);
                  final isSelected = selectedCategory?.toLowerCase() ==
                      item.category.toLowerCase();
                  return GestureDetector(
                    onTap: () =>
                        onCategoryTap(isSelected ? null : item.category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? meta.color.withValues(alpha: 0.25)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? meta.color : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 14, color: meta.color),
                          const SizedBox(width: 6),
                          Text(
                            '${item.category}: ${currency.format(item.totalAmount)}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
