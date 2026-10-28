import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'secure_storage_service.dart';

enum PinVerificationResult {
  success,
  incorrect,
  invalidPin,
  temporarilyDisabled,
  notEnrolled,
  storageError,
}

class PinSecurityService {
  PinSecurityService({SecureStorageService? storage})
    : _storage = storage ?? SecureStorageService();

  static const int _saltLength = 16;
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static const int _derivationIterations = 120000;

  final SecureStorageService _storage;
  final Pbkdf2 _derivation = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _derivationIterations,
    bits: 256,
  );

  Future<bool> enrollPin(String pin) async {
    if (!_isValidPin(pin)) return false;

    final salt = _randomBytes(_saltLength);
    final verifier = await _deriveVerifier(pin, salt);
    final saltValue = base64UrlEncode(salt);
    final verifierValue = base64UrlEncode(verifier);

    final saltStored = await _storage.write(
      SecureStorageService.pinSaltKey,
      saltValue,
    );
    final verifierStored = saltStored
        ? await _storage.write(
            SecureStorageService.pinVerifierKey,
            verifierValue,
          )
        : false;

    if (!verifierStored) {
      await _storage.delete(SecureStorageService.pinSaltKey);
      return false;
    }

    await _storage.delete(SecureStorageService.pinFailedAttemptsKey);
    await _storage.delete(SecureStorageService.pinDisabledUntilKey);
    return true;
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    if (!_isValidPin(pin)) return PinVerificationResult.invalidPin;

    final disabledUntil = await _readDisabledUntil();
    if (disabledUntil != null) {
      if (DateTime.now().isBefore(disabledUntil)) {
        return PinVerificationResult.temporarilyDisabled;
      }
      await _storage.delete(SecureStorageService.pinDisabledUntilKey);
      await _storage.delete(SecureStorageService.pinFailedAttemptsKey);
    }

    final saltValue = await _storage.read(SecureStorageService.pinSaltKey);
    final verifierValue = await _storage.read(
      SecureStorageService.pinVerifierKey,
    );
    if (saltValue == null || verifierValue == null) {
      return PinVerificationResult.notEnrolled;
    }

    try {
      final salt = base64Url.decode(saltValue);
      final expectedVerifier = base64Url.decode(verifierValue);
      final actualVerifier = await _deriveVerifier(pin, salt);

      if (_constantTimeEquals(actualVerifier, expectedVerifier)) {
        await _storage.delete(SecureStorageService.pinFailedAttemptsKey);
        return PinVerificationResult.success;
      }
    } catch (_) {
      return PinVerificationResult.storageError;
    }

    final attempts = await _readFailedAttempts();
    final nextAttempts = attempts + 1;
    if (nextAttempts >= _maxFailedAttempts) {
      final disabledUntil = DateTime.now().add(_lockoutDuration);
      final disabledStored = await _storage.write(
        SecureStorageService.pinDisabledUntilKey,
        disabledUntil.millisecondsSinceEpoch.toString(),
      );
      final attemptsStored = await _storage.write(
        SecureStorageService.pinFailedAttemptsKey,
        nextAttempts.toString(),
      );
      return disabledStored && attemptsStored
          ? PinVerificationResult.temporarilyDisabled
          : PinVerificationResult.storageError;
    } else {
      final attemptsStored = await _storage.write(
        SecureStorageService.pinFailedAttemptsKey,
        nextAttempts.toString(),
      );
      if (!attemptsStored) return PinVerificationResult.storageError;
    }
    return PinVerificationResult.incorrect;
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  Future<List<int>> _deriveVerifier(String pin, List<int> salt) async {
    final secretKey = await _derivation.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<int> _readFailedAttempts() async {
    final value = await _storage.read(
      SecureStorageService.pinFailedAttemptsKey,
    );
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<DateTime?> _readDisabledUntil() async {
    final value = await _storage.read(SecureStorageService.pinDisabledUntilKey);
    final milliseconds = int.tryParse(value ?? '');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
