import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/security/quick_access_controller.dart';
import 'package:coop_frontend/security/quick_access_service.dart';
import 'support/quick_access_fakes.dart';

void main() {
  test(
    'An enrolled PIN cannot create a session when no session was restored',
    () async {
      var validations = 0;
      final service = FakeQuickAccessService();
      final controller = QuickAccessController(
        service: service,
        currentUserId: () => null,
        validateSession: (_) async {
          validations++;
          return false;
        },
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.unlockWithPin('1234');
      expect(controller.ready, isTrue);
      expect(controller.hasSession, isFalse);
      expect(service.pinVerifications, 0);
      expect(validations, 0);
    },
  );
  test(
    'Startup locks an enrolled session, wrong PIN never reaches the server',
    () async {
      var validations = 0;
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => 'member-A',
        validateSession: (_) async {
          validations++;
          return false;
        },
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.locked, isTrue);
      await controller.unlockWithPin('9999');
      expect(controller.locked, isTrue);
      expect(validations, 0);
      await controller.unlockWithPin('1234');
      expect(validations, 1);
      expect(controller.locked, isFalse);
    },
  );

  test(
    'Skipped startup requires password instead of accepting the restored session',
    () async {
      String? current = 'member-A';
      final controller = QuickAccessController(
        service: FakeQuickAccessService(method: QuickAccessMethod.skipped),
        currentUserId: () => current,
        validateSession: (_) async => false,
        endSession: () async {
          current = null;
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.ready, isTrue);
      expect(controller.hasSession, isFalse);
      expect(current, isNull);
    },
  );

  test('Another account cannot use the saved quick-access settings', () async {
    String? current = 'member-B';
    final controller = QuickAccessController(
      service: FakeQuickAccessService(owner: 'member-A'),
      currentUserId: () => current,
      validateSession: (_) async => false,
      endSession: () async {
        current = null;
      },
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.hasSession, isFalse);
    expect(current, isNull);
  });

  test(
    'Correct local PIN cannot unlock an expired or rejected Supabase session',
    () async {
      String? current = 'member-A';
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => current,
        validateSession: (_) async =>
            throw const InvalidQuickAccessSession('Please sign in again.'),
        endSession: () async {
          current = null;
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.unlockWithPin('1234');
      expect(controller.hasSession, isFalse);
      expect(controller.locked, isTrue);
      expect(controller.redirectToStart, isTrue);
    },
  );

  test('Connection failure stays locked and permits retry', () async {
    var connected = false;
    final controller = QuickAccessController(
      service: FakeQuickAccessService(),
      currentUserId: () => 'member-A',
      validateSession: (_) async {
        if (!connected) throw StateError('Check your connection.');
        return false;
      },
      endSession: () async {},
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.unlockWithPin('1234');
    expect(controller.locked, isTrue);
    expect(controller.hasSession, isTrue);
    connected = true;
    await controller.unlockWithPin('1234');
    expect(controller.locked, isFalse);
  });

  test(
    'Cancelled biometric prompt stays locked; successful biometric still validates session',
    () async {
      var validations = 0;
      final service = FakeQuickAccessService(
        method: QuickAccessMethod.biometric,
      )..acceptBiometrics = false;
      final controller = QuickAccessController(
        service: service,
        currentUserId: () => 'member-A',
        validateSession: (_) async {
          validations++;
          return false;
        },
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.unlockWithBiometrics();
      expect(controller.locked, isTrue);
      expect(validations, 0);
      service.acceptBiometrics = true;
      await controller.unlockWithBiometrics();
      expect(controller.locked, isFalse);
      expect(validations, 1);
    },
  );

  test(
    'A password-reset flag routes to password setup instead of dashboard',
    () async {
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => 'member-A',
        validateSession: (_) async => true,
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.unlockWithPin('1234');
      expect(controller.requiresPasswordChange, isTrue);
      expect(controller.redirectToStart, isTrue);
      expect(controller.locked, isTrue);
      controller.acknowledgeRedirect();
      expect(controller.requiresPasswordChange, isTrue);
    },
  );

  test(
    'Account change during validation cannot release a stale unlock',
    () async {
      String? current = 'member-A';
      final pending = Completer<bool>();
      final validationStarted = Completer<void>();
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => current,
        validateSession: (_) {
          validationStarted.complete();
          return pending.future;
        },
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final unlock = controller.unlockWithPin('1234');
      await validationStarted.future;
      current = 'member-B';
      controller.handleAuthUserChanged(current);
      pending.complete(false);
      await unlock;
      expect(controller.hasSession, isFalse);
      expect(controller.locked, isTrue);
    },
  );

  test('Logout clears enrollment and blocks quick access', () async {
    final service = FakeQuickAccessService();
    final controller = QuickAccessController(
      service: service,
      currentUserId: () => 'member-A',
      validateSession: (_) async => false,
      endSession: () async {},
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.clearAfterSignOut();
    expect(service.clears, 1);
    expect(controller.hasSession, isFalse);
    expect(controller.redirectToStart, isTrue);
  });
}
