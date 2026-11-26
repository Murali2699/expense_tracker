import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<String> getBiometricLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (Platform.isIOS) {
        if (types.contains(BiometricType.face)) return 'Face ID';
        if (types.contains(BiometricType.fingerprint)) return 'Touch ID';
        return 'Face ID';
      }
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.face)) return 'Face Unlock';
      return 'Biometric Lock';
    } on PlatformException {
      return Platform.isIOS ? 'Face ID' : 'Biometric Lock';
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
