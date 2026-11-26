import 'dart:io';
import 'package:quick_actions/quick_actions.dart';

typedef QuickActionHandler = Future<void> Function(String actionType);

class QuickActionsService {
  QuickActionsService._();
  static final QuickActionsService instance = QuickActionsService._();

  static const actionEnableBiometric = 'enable_face_id';
  static const actionDisableBiometric = 'disable_face_id';

  final QuickActions _quickActions = const QuickActions();
  bool _initialized = false;

  Future<void> initialize(QuickActionHandler onAction) async {
    if (_initialized) return;
    _initialized = true;

    await _quickActions.initialize((String shortcutType) {
      onAction(shortcutType);
    });

    final label = Platform.isIOS ? 'Face ID' : 'Biometric Lock';
    await _quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: actionEnableBiometric,
        localizedTitle: 'Enable $label',
        icon: Platform.isIOS ? 'faceid' : null,
      ),
      ShortcutItem(
        type: actionDisableBiometric,
        localizedTitle: 'Disable $label',
        icon: Platform.isIOS ? 'lock_open' : null,
      ),
    ]);
  }
}
