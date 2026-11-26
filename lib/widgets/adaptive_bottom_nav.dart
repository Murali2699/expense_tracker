import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavItemData {
  const NavItemData({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class AdaptiveBottomNav extends StatefulWidget {
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
  State<AdaptiveBottomNav> createState() => _AdaptiveBottomNavState();
}

class _AdaptiveBottomNavState extends State<AdaptiveBottomNav> {
  double? _dragFraction;

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
        children: List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final active = i == widget.selectedIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: active ? AppTheme.accentSoft : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelected(i),
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
                            fontSize: 10,
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
    final count = widget.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const pad = 6.0;
              final innerWidth = constraints.maxWidth - pad * 2;
              final itemWidth = innerWidth / count;
              final activePos = (_dragFraction ?? widget.selectedIndex.toDouble())
                  .clamp(0.0, (count - 1).toDouble());

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  final idx = ((details.localPosition.dx - pad) / itemWidth)
                      .clamp(0.0, (count - 1).toDouble());
                  setState(() => _dragFraction = idx);
                },
                onHorizontalDragUpdate: (details) {
                  final idx = ((details.localPosition.dx - pad) / itemWidth)
                      .clamp(0.0, (count - 1).toDouble());
                  setState(() => _dragFraction = idx);
                },
                onHorizontalDragEnd: (_) {
                  final target = (_dragFraction ?? widget.selectedIndex.toDouble())
                      .round()
                      .clamp(0, count - 1);
                  setState(() => _dragFraction = null);
                  widget.onSelected(target);
                },
                child: Container(
                  padding: const EdgeInsets.all(pad),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.84),
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
                  child: Stack(
                    children: [
                      // Sliding iOS bubble pill
                      AnimatedPositioned(
                        duration: _dragFraction != null
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: activePos * itemWidth,
                        top: 0,
                        bottom: 0,
                        width: itemWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(count, (i) {
                          final item = widget.items[i];
                          final active = i == activePos.round();
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => widget.onSelected(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 21,
                                      color: active
                                          ? AppTheme.accent
                                          : AppTheme.textMuted,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? AppTheme.accent
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
