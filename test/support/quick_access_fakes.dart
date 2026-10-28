import 'package:coop_frontend/security/secure_storage_service.dart';
import 'package:coop_frontend/security/quick_access_service.dart';
import 'package:coop_frontend/security/pin_security_service.dart';

class MemorySecureStorage extends SecureStorageService {
  final values = <String, String>{};
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async {
    if (failDeletes) return false;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clearSecurityData() async {
    if (failDeletes) return false;
    values.removeWhere((key, _) => key.startsWith('security.'));
    return true;
  }
}

class FakeBiometrics implements BiometricAuthenticator {
  bool available = true;
  bool accepted = true;
  int authentications = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    authentications++;
    return accepted;
  }
}

// Widget/controller tests substitute local hardware and PIN verification;
// service tests exercise real PBKDF2 PIN enrollment separately.
class FakeQuickAccessService extends QuickAccessService {
  FakeQuickAccessService({
    this.owner = 'member-A',
    this.method = QuickAccessMethod.pin,
  }) : super(storage: MemorySecureStorage(), biometrics: FakeBiometrics());

  String? owner;
  QuickAccessMethod method;
  String? enrolledPin;
  String expectedPin = '1234';
  bool acceptBiometrics = true;
  int clears = 0;
  int pinVerifications = 0;

  @override
  Future<QuickAccessMethod> methodFor(String userId) async =>
      userId == owner ? method : QuickAccessMethod.none;

  @override
  Future<void> clear() async {
    owner = null;
    method = QuickAccessMethod.none;
    clears++;
  }

  @override
  Future<void> enrollPin(String userId, String pin) async {
    owner = userId;
    method = QuickAccessMethod.pin;
    enrolledPin = pin;
    expectedPin = pin;
  }

  @override
  Future<void> skip(String userId) async {
    owner = userId;
    method = QuickAccessMethod.skipped;
  }

  @override
  Future<bool> enrollBiometrics(String userId) async {
    if (!acceptBiometrics) return false;
    owner = userId;
    method = QuickAccessMethod.biometric;
    return true;
  }

  @override
  Future<PinVerificationResult> verifyPin(String userId, String pin) async {
    pinVerifications++;
    if (owner != userId || method != QuickAccessMethod.pin) {
      return PinVerificationResult.notEnrolled;
    }
    return pin == expectedPin
        ? PinVerificationResult.success
        : PinVerificationResult.incorrect;
  }

  @override
  Future<bool> verifyBiometrics(String userId) async =>
      owner == userId &&
      method == QuickAccessMethod.biometric &&
      acceptBiometrics;
}
