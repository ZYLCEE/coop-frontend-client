import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coop_frontend/quick_access_gate.dart';
import 'package:coop_frontend/confirmpasscreen.dart';
import 'package:coop_frontend/quick_unlock_screen.dart';
import 'package:coop_frontend/quickaccesssetupscreen.dart';
import 'package:coop_frontend/security/quick_access_controller.dart';
import 'package:coop_frontend/security/quick_access_service.dart';
import 'support/quick_access_fakes.dart';

void main() {
  testWidgets(
    'A restored session requiring a password change opens setup after local unlock',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => 'member-A',
        validateSession: (_) async => true,
        endSession: () async {},
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (context, child) => QuickAccessGate(
            controller: controller,
            navigatorKey: key,
            authEvents: const Stream<AuthState>.empty(),
            child: child!,
          ),
          home: QuickAccessEntry(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmPassScreen), findsOneWidget);
      expect(find.byType(QuickUnlockScreen), findsNothing);
    },
  );
  void largeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> enterPin(WidgetTester tester, List<String> digits) async {
    for (final digit in digits) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Setup saves PIN only after confirmation', (tester) async {
    largeScreen(tester);
    final service = FakeQuickAccessService(method: QuickAccessMethod.none);
    final controller = QuickAccessController(
      service: service,
      currentUserId: () => 'member-A',
    );
    addTearDown(controller.dispose);
    await controller.activateAfterPasswordLogin(mustChangePassword: false);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: QuickAccessSetupScreen(
          controller: controller,
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterPin(tester, ['1', '2', '3', '4']);
    expect(find.text('CONFIRM YOUR 4-DIGIT PIN'), findsOneWidget);
    expect(service.enrolledPin, isNull);
    await enterPin(tester, ['1', '2', '3', '4']);
    expect(service.enrolledPin, '1234');
    expect(completed, isTrue);
  });

  testWidgets('Mismatched confirmation does not enroll the PIN', (
    tester,
  ) async {
    largeScreen(tester);
    final service = FakeQuickAccessService(method: QuickAccessMethod.none);
    final controller = QuickAccessController(
      service: service,
      currentUserId: () => 'member-A',
    );
    addTearDown(controller.dispose);
    await controller.activateAfterPasswordLogin(mustChangePassword: false);
    await tester.pumpWidget(
      MaterialApp(
        home: QuickAccessSetupScreen(
          controller: controller,
          onCompleted: () => fail('Must not complete mismatched PIN setup'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterPin(tester, ['1', '2', '3', '4']);
    await enterPin(tester, ['4', '3', '2', '1']);
    expect(service.enrolledPin, isNull);
    expect(
      find.text('PINs do not match. Enter a new PIN and confirm it.'),
      findsOneWidget,
    );
  });

  testWidgets('Skip is saved and continues without enrollment', (tester) async {
    largeScreen(tester);
    final service = FakeQuickAccessService(method: QuickAccessMethod.none);
    final controller = QuickAccessController(
      service: service,
      currentUserId: () => 'member-A',
    );
    addTearDown(controller.dispose);
    await controller.activateAfterPasswordLogin(mustChangePassword: false);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: QuickAccessSetupScreen(
          controller: controller,
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(service.method, QuickAccessMethod.skipped);
    expect(service.enrolledPin, isNull);
    expect(completed, isTrue);
  });

  testWidgets('Cancelling biometrics keeps setup open', (tester) async {
    largeScreen(tester);
    final service = FakeQuickAccessService(method: QuickAccessMethod.none)
      ..acceptBiometrics = false;
    final controller = QuickAccessController(
      service: service,
      currentUserId: () => 'member-A',
    );
    addTearDown(controller.dispose);
    await controller.activateAfterPasswordLogin(mustChangePassword: false);
    await tester.pumpWidget(
      MaterialApp(
        home: QuickAccessSetupScreen(
          controller: controller,
          onCompleted: () =>
              fail('Cancelled biometrics must not complete setup'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biometric'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Biometric setup was cancelled. Try again, choose PIN, or skip.',
      ),
      findsOneWidget,
    );
    expect(service.method, QuickAccessMethod.none);
  });

  testWidgets(
    'Gate hides protected routes at startup and again after backgrounding',
    (tester) async {
      largeScreen(tester);
      String? current = 'member-A';
      final controller = QuickAccessController(
        service: FakeQuickAccessService(),
        currentUserId: () => current,
        validateSession: (_) async => false,
        endSession: () async {
          current = null;
        },
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (context, child) => QuickAccessGate(
            controller: controller,
            navigatorKey: key,
            authEvents: const Stream<AuthState>.empty(),
            child: child!,
          ),
          home: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Scaffold(
              body: Text(
                controller.hasSession ? 'Protected content' : 'Password login',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuickUnlockScreen), findsOneWidget);
      expect(find.text('Protected content'), findsNothing);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Protected content'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Protected content'), findsNothing);
      expect(find.byType(QuickUnlockScreen), findsOneWidget);
      await tester.tap(find.text('Use Member ID and password instead'));
      await tester.pumpAndSettle();
      expect(find.text('Protected content'), findsNothing);
      expect(find.text('Password login'), findsOneWidget);
    },
  );
}
