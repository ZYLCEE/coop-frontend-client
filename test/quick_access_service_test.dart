import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coop_frontend/security/pin_security_service.dart';
import 'package:coop_frontend/security/quick_access_service.dart';
import 'package:coop_frontend/security/secure_auth_storage.dart';
import 'package:coop_frontend/security/secure_storage_service.dart';
import 'support/quick_access_fakes.dart';

void main() {
  test(
    'Existing SDK session migrates to secure storage and is removed from old storage',
    () async {
      final memory = MemorySecureStorage();
      final previous = MemorySessionStorage('old-test-session');
      final storage = SecureAuthStorage(
        sessionKey: 'auth.session',
        storage: memory,
        previousStorage: previous,
      );
      await storage.initialize();
      expect(await storage.accessToken(), 'old-test-session');
      expect(await previous.accessToken(), isNull);
    },
  );

  test('A failed migration does not discard the original session', () async {
    final memory = MemorySecureStorage()..failWrites = true;
    final previous = MemorySessionStorage('old-test-session');
    final storage = SecureAuthStorage(
      sessionKey: 'auth.session',
      storage: memory,
      previousStorage: previous,
    );
    await expectLater(storage.initialize(), throwsStateError);
    expect(await previous.accessToken(), 'old-test-session');
  });
  test(
    'PIN is hashed, account-bound, and survives a service restart',
    () async {
      final storage = MemorySecureStorage();
      final service = QuickAccessService(
        storage: storage,
        biometrics: FakeBiometrics(),
      );
      await service.enrollPin('member-A', '1234');
      expect(storage.values.values, isNot(contains('1234')));
      final restored = QuickAccessService(
        storage: storage,
        biometrics: FakeBiometrics(),
      );
      expect(await restored.methodFor('member-A'), QuickAccessMethod.pin);
      expect(
        await restored.verifyPin('member-B', '1234'),
        PinVerificationResult.notEnrolled,
      );
      expect(
        await restored.verifyPin('member-A', '1234'),
        PinVerificationResult.success,
      );
    },
  );

  test(
    'Five wrong PIN attempts lock out even the correct PIN, including after restart',
    () async {
      final storage = MemorySecureStorage();
      final service = QuickAccessService(
        storage: storage,
        biometrics: FakeBiometrics(),
      );
      await service.enrollPin('member-A', '1234');
      for (var attempt = 0; attempt < 4; attempt++) {
        expect(
          await service.verifyPin('member-A', '9999'),
          PinVerificationResult.incorrect,
        );
      }
      expect(
        await service.verifyPin('member-A', '9999'),
        PinVerificationResult.temporarilyDisabled,
      );
      final restored = QuickAccessService(
        storage: storage,
        biometrics: FakeBiometrics(),
      );
      expect(
        await restored.verifyPin('member-A', '1234'),
        PinVerificationResult.temporarilyDisabled,
      );
      storage.values[SecureStorageService.pinDisabledUntilKey] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch
          .toString();
      expect(
        await restored.verifyPin('member-A', '1234'),
        PinVerificationResult.success,
      );
    },
  );

  test(
    'Skipping removes enrolled quick access without removing the current auth session',
    () async {
      final storage = MemorySecureStorage();
      storage.values['auth.session'] = 'test-session';
      final service = QuickAccessService(
        storage: storage,
        biometrics: FakeBiometrics(),
      );
      await service.enrollPin('member-A', '1234');
      await service.skip('member-A');
      expect(await service.methodFor('member-A'), QuickAccessMethod.skipped);
      expect(storage.values[SecureStorageService.pinVerifierKey], isNull);
      expect(storage.values['auth.session'], 'test-session');
    },
  );

  test('Biometric cancellation does not erase an existing PIN', () async {
    final storage = MemorySecureStorage();
    final biometric = FakeBiometrics()..accepted = false;
    final service = QuickAccessService(storage: storage, biometrics: biometric);
    await service.enrollPin('member-A', '1234');
    expect(await service.enrollBiometrics('member-A'), isFalse);
    expect(await service.methodFor('member-A'), QuickAccessMethod.pin);
  });

  test(
    'Biometrics are checked on enrollment and again on unlock for the bound user',
    () async {
      final storage = MemorySecureStorage();
      final biometric = FakeBiometrics();
      final service = QuickAccessService(
        storage: storage,
        biometrics: biometric,
      );
      expect(await service.enrollBiometrics('member-A'), isTrue);
      expect(biometric.authentications, 1);
      expect(await service.verifyBiometrics('member-B'), isFalse);
      expect(biometric.authentications, 1);
      expect(await service.verifyBiometrics('member-A'), isTrue);
      expect(biometric.authentications, 2);
      biometric.available = false;
      await expectLater(service.verifyBiometrics('member-A'), throwsStateError);
    },
  );

  test('Failed secure writes cannot create an enrolled PIN', () async {
    final storage = MemorySecureStorage()..failWrites = true;
    final service = QuickAccessService(
      storage: storage,
      biometrics: FakeBiometrics(),
    );
    await expectLater(service.enrollPin('member-A', '1234'), throwsStateError);
    expect(await service.methodFor('member-A'), QuickAccessMethod.none);
  });

  test(
    'Supabase session storage persists and removes tokens through secure storage',
    () async {
      final memory = MemorySecureStorage();
      final storage = SecureAuthStorage(
        sessionKey: 'auth.session',
        storage: memory,
      );
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession('test-session');
      expect(await storage.accessToken(), 'test-session');
      expect(await storage.hasAccessToken(), isTrue);
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      memory.failWrites = true;
      await expectLater(
        storage.persistSession('test-session'),
        throwsStateError,
      );
    },
  );
}

class MemorySessionStorage extends LocalStorage {
  MemorySessionStorage(this.session);
  String? session;
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => session;
  @override
  Future<bool> hasAccessToken() async => session != null;
  @override
  Future<void> persistSession(String persistSessionString) async {
    session = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    session = null;
  }
}
