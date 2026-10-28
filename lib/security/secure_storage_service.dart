import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? _createStorage();

  final FlutterSecureStorage _storage;

  static const String biometricEnabledKey = 'security.biometric_enabled';
  static const String pinSaltKey = 'security.pin_salt';
  static const String pinVerifierKey = 'security.pin_verifier';
  static const String pinFailedAttemptsKey = 'security.pin_failed_attempts';
  static const String pinDisabledUntilKey = 'security.pin_disabled_until';
  static const String quickAccessUserIdKey = 'security.quick_access_user_id';
  static const String quickAccessMethodKey = 'security.quick_access_method';

  static const Set<String> _securityKeys = {
    biometricEnabledKey,
    pinSaltKey,
    pinVerifierKey,
    pinFailedAttemptsKey,
    pinDisabledUntilKey,
    quickAccessUserIdKey,
    quickAccessMethodKey,
  };

  static FlutterSecureStorage _createStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
  }

  Future<bool> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<bool> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearSecurityData() async {
    try {
      for (final key in _securityKeys) {
        await _storage.delete(key: key);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
