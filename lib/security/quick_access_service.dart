import 'package:local_auth/local_auth.dart';
import 'pin_security_service.dart';
import 'secure_storage_service.dart';

enum QuickAccessMethod { none, pin, biometric, skipped }

abstract class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

class DeviceBiometrics implements BiometricAuthenticator {
  DeviceBiometrics({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _authentication.isDeviceSupported() &&
          await _authentication.canCheckBiometrics &&
          (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() => _authentication.authenticate(
    localizedReason: 'Unlock your cooperative account',
    options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
  );
}

class QuickAccessService {
  QuickAccessService({
    SecureStorageService? storage,
    BiometricAuthenticator? biometrics,
  }) : _storage = storage ?? SecureStorageService(),
       biometrics = biometrics ?? DeviceBiometrics() {
    _pin = PinSecurityService(storage: _storage);
  }

  final SecureStorageService _storage;
  final BiometricAuthenticator biometrics;
  late final PinSecurityService _pin;

  Future<QuickAccessMethod> methodFor(String userId) async {
    if (await _storage.read(SecureStorageService.quickAccessUserIdKey) !=
        userId) {
      return QuickAccessMethod.none;
    }
    final method = await _storage.read(
      SecureStorageService.quickAccessMethodKey,
    );
    if (method == 'pin') {
      final salt = await _storage.read(SecureStorageService.pinSaltKey);
      final verifier = await _storage.read(SecureStorageService.pinVerifierKey);
      return salt != null && verifier != null
          ? QuickAccessMethod.pin
          : QuickAccessMethod.none;
    }
    if (method == 'biometric' &&
        await _storage.read(SecureStorageService.biometricEnabledKey) ==
            'true') {
      return QuickAccessMethod.biometric;
    }
    return method == 'skipped'
        ? QuickAccessMethod.skipped
        : QuickAccessMethod.none;
  }

  Future<void> clear() async {
    if (!await _storage.clearSecurityData()) {
      throw StateError('Unable to clear quick-access settings on this device.');
    }
  }

  Future<void> _saveOwner(String userId, QuickAccessMethod method) async {
    if (userId.isEmpty ||
        !await _storage.write(
          SecureStorageService.quickAccessUserIdKey,
          userId,
        ) ||
        !await _storage.write(
          SecureStorageService.quickAccessMethodKey,
          method.name,
        )) {
      await _storage.clearSecurityData();
      throw StateError('Unable to save quick access on this device.');
    }
  }

  Future<void> enrollPin(String userId, String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw StateError('Enter a 4-digit PIN.');
    }
    await clear();
    if (!await _pin.enrollPin(pin)) {
      throw StateError('Unable to save your PIN. Please try again.');
    }
    await _saveOwner(userId, QuickAccessMethod.pin);
  }

  Future<bool> enrollBiometrics(String userId) async {
    if (!await biometrics.isAvailable()) {
      throw StateError(
        'Biometrics are unavailable. Enroll a fingerprint or face in your device settings, or choose PIN.',
      );
    }
    if (!await biometrics.authenticate()) return false;
    await clear();
    if (!await _storage.write(
      SecureStorageService.biometricEnabledKey,
      'true',
    )) {
      throw StateError('Unable to save biometric access on this device.');
    }
    await _saveOwner(userId, QuickAccessMethod.biometric);
    return true;
  }

  Future<void> skip(String userId) async {
    await clear();
    await _saveOwner(userId, QuickAccessMethod.skipped);
  }

  Future<PinVerificationResult> verifyPin(String userId, String pin) async {
    if (await methodFor(userId) != QuickAccessMethod.pin) {
      return PinVerificationResult.notEnrolled;
    }
    return _pin.verifyPin(pin);
  }

  Future<bool> verifyBiometrics(String userId) async {
    if (await methodFor(userId) != QuickAccessMethod.biometric) return false;
    if (!await biometrics.isAvailable()) {
      throw StateError(
        'Biometrics are unavailable. Use your Member ID and password instead.',
      );
    }
    return biometrics.authenticate();
  }
}
