import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutBack),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.15,
            colors: [
              Color(0xFF0E2923),
              Color(0xFF0B0F14),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, child) {
                      final t = _pulseCtrl.value;
                      final floatY = math.sin(t * math.pi) * -6.0;
                      return Transform.translate(
                        offset: Offset(0, floatY),
                        child: Container(
                          width: 160,
                          height: 160,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(38),
                            border: Border.all(
                              color: AppTheme.accent
                                  .withValues(alpha: 0.45 + 0.4 * t),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent
                                    .withValues(alpha: 0.25 + 0.25 * t),
                                blurRadius: 34 + 18 * t,
                                spreadRadius: 2 + 4 * t,
                              ),
                              BoxShadow(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.14 + 0.12 * t),
                                blurRadius: 56 + 14 * t,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppTheme.accent,
                          size: 68,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SlideTransition(
                  position: _textSlide,
                  child: const Column(
                    children: [
                      Text(
                        'SpendWise',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track • Save • Prosper',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Animated rising expense chart bars
                AnimatedBuilder(
                  animation: _introCtrl,
                  builder: (_, _) {
                    const heights = [16.0, 28.0, 20.0, 36.0, 26.0];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(heights.length, (i) {
                        final progress =
                            ((_introCtrl.value - i * 0.08) / 0.6).clamp(0.0, 1.0);
                        return Container(
                          width: 8,
                          height: 6 + heights[i] * progress,
                          margin: const EdgeInsets.symmetric(horizontal: 3.5),
                          decoration: BoxDecoration(
                            color: i == 3
                                ? AppTheme.accent
                                : AppTheme.accent.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
