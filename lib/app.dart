import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/api_client.dart';
import 'core/biometric_service.dart';
import 'core/quick_actions_service.dart';
import 'core/secure_storage.dart';
import 'core/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class _UnfocusNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp>
    with WidgetsBindingObserver {
  final _storage = SecureStorageService.instance;
  final _biometrics = BiometricService.instance;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _initializing = true;
  bool _loggedIn = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Face ID';
  bool _locked = false;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    SyncService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() {
        _inBackground = true;
        if (state == AppLifecycleState.paused && _biometricEnabled && _loggedIn) {
          _locked = true;
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      setState(() => _inBackground = false);
      if (_loggedIn) {
        SyncService.instance.flush();
      }
    }
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      dotenv.load(fileName: '.env'),
      _storage.getAccessToken(),
      _biometrics.isAvailable(),
      _storage.isBiometricEnabled(),
      _biometrics.getBiometricLabel(),
      QuickActionsService.instance.initialize(_handleQuickAction),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);

    final token = results[1] as String?;
    final bioAvail = results[2] as bool;
    final bioEnabled = results[3] as bool;
    final bioLabel = results[4] as String;

    if (!mounted) return;
    if (token != null) {
      SyncService.instance.start();
    }
    setState(() {
      _loggedIn = token != null;
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled && bioAvail;
      _biometricLabel = bioLabel;
      _locked = _loggedIn && _biometricEnabled;
      _initializing = false;
    });
  }

  Future<void> _handleQuickAction(String action) async {
    if (!_biometricAvailable) return;
    final enable = action == QuickActionsService.actionEnableBiometric;
    final verified = await _biometrics.authenticate(
      reason: enable
          ? 'Authenticate to enable $_biometricLabel'
          : 'Authenticate to disable $_biometricLabel',
    );
    if (!verified) return;
    await _setBiometricEnabled(enable);
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          enable
              ? '$_biometricLabel enabled'
              : '$_biometricLabel disabled',
        ),
      ),
    );
  }

  Future<void> _setBiometricEnabled(bool enabled) async {
    await _storage.setBiometricEnabled(enabled);
    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  Future<void> _logout() async {
    if (_biometricEnabled) {
      await _storage.clearAccessTokenOnly();
    } else {
      await ApiClient.instance.logout();
    }
    if (mounted) {
      setState(() {
        _loggedIn = false;
        _locked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorObservers: [_UnfocusNavigatorObserver()],
      theme: AppTheme.dark,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              ?child,
              // Privacy overlay when backgrounded so OS task switcher doesn't leak expenses
              if (_inBackground)
                Container(
                  color: AppTheme.bg,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 48,
                    color: AppTheme.accent,
                  ),
                ),
            ],
          ),
        );
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_initializing) {
      return const SplashScreen();
    }
    if (!_loggedIn) {
      return LoginScreen(
        biometricEnabled: _biometricEnabled,
        biometricAvailable: _biometricAvailable,
        biometricLabel: _biometricLabel,
        onLoggedIn: () {
          SyncService.instance.start();
          setState(() => _loggedIn = true);
        },
      );
    }
    if (_locked) {
      return LockScreen(
        biometricLabel: _biometricLabel,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return HomeScreen(
      biometricEnabled: _biometricEnabled,
      biometricAvailable: _biometricAvailable,
      biometricLabel: _biometricLabel,
      onToggleBiometric: _setBiometricEnabled,
      onLogout: _logout,
    );
  }
}
