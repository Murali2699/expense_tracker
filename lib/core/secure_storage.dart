import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUsername = 'username';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kBiometricPrompted = 'biometric_prompted';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? username,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    if (username != null) {
      await _storage.write(key: _kUsername, value: username);
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getUsername() => _storage.read(key: _kUsername);

  Future<void> clearAccessTokenOnly() async {
    await _storage.delete(key: _kAccessToken);
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUsername);
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _kBiometricEnabled);
    return v == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _kBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> wasBiometricPrompted() async {
    final v = await _storage.read(key: _kBiometricPrompted);
    return v == 'true';
  }

  Future<void> setBiometricPrompted() async {
    await _storage.write(key: _kBiometricPrompted, value: 'true');
  }
}
