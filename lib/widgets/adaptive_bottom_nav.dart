import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavItemData {
  const NavItemData({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class AdaptiveBottomNav extends StatelessWidget {
  const AdaptiveBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItemData> items;

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: isIos ? _buildIosBubbleNav() : _buildAndroidBoxNav(),
    );
  }

  Widget _buildAndroidBoxNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final active = i == selectedIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: active ? AppTheme.accentSoft : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppTheme.accent : AppTheme.border,
                        width: active ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: active ? AppTheme.accent : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? AppTheme.accent : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildIosBubbleNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final active = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.accent.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                        border: active
                            ? Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.55),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 21,
                            color: active ? AppTheme.accent : AppTheme.textMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  active ? AppTheme.accent : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
