import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/biometric_service.dart';
import '../core/secure_storage.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.biometricLabel = 'Face ID',
  });

  final VoidCallback onLoggedIn;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final String biometricLabel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _canBiometricLogin = false;
  String? _error;

  late final AnimationController _entranceCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricSession();
    });
  }

  Future<void> _checkBiometricSession() async {
    if (!widget.biometricEnabled || !widget.biometricAvailable) return;
    final refresh = await SecureStorageService.instance.getRefreshToken();
    final savedUser = await SecureStorageService.instance.getUsername();
    if (!mounted || refresh == null) return;
    setState(() {
      _canBiometricLogin = true;
      if (savedUser != null && _usernameCtrl.text.isEmpty) {
        _usernameCtrl.text = savedUser;
      }
    });
    await _loginWithBiometrics();
  }

  Future<void> _loginWithBiometrics() async {
    if (_loading) return;
    final ok = await BiometricService.instance.authenticate(
      reason: 'Sign in with ${widget.biometricLabel}',
    );
    if (!ok || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final refreshed = await ApiClient.instance.loginWithBiometricSession();
    if (!mounted) return;
    setState(() => _loading = false);

    if (refreshed) {
      widget.onLoggedIn();
    } else {
      setState(() {
        _canBiometricLogin = false;
        _error = 'Session expired. Please sign in with your password.';
      });
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _glowCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.instance.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) widget.onLoggedIn();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AnimatedBuilder(
                          animation: _glowCtrl,
                          builder: (_, child) {
                            final t = _glowCtrl.value;
                            final floatY = math.sin(t * math.pi) * -4.0;
                            return Transform.translate(
                              offset: Offset(0, floatY),
                              child: Container(
                                width: 132,
                                height: 132,
                                padding: const EdgeInsets.all(12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: AppTheme.accent
                                        .withValues(alpha: 0.5 + 0.4 * t),
                                    width: 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.28 + 0.22 * t),
                                      blurRadius: 28 + 16 * t,
                                      spreadRadius: 2 + 3 * t,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.14 + 0.1 * t),
                                      blurRadius: 48 + 12 * t,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppTheme.accent,
                                size: 54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Expense Tracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to sync your personal expenses securely.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.danger),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.danger),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _usernameCtrl,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Enter username (min 3 chars)'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Enter password (min 8 chars)'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF032318),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      if (_canBiometricLogin) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loginWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text('Sign in with ${widget.biometricLabel}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
