import 'package:flutter/material.dart';

import '../core/biometric_service.dart';
import '../theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.biometricLabel,
    required this.onUnlocked,
  });

  final String biometricLabel;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await BiometricService.instance.authenticate(
      reason: 'Unlock Expense Tracker with ${widget.biometricLabel}',
    );
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (ok) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppTheme.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Expense Tracker Locked',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify with ${widget.biometricLabel} to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _authenticate,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text('Unlock with ${widget.biometricLabel}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF032318),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
