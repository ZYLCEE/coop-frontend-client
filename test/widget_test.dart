import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/loginscreen.dart';
import 'package:coop_frontend/confirmpasscreen.dart';

void main() {
  Future<void> openLogin(WidgetTester tester, LoginScreen screen) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  testWidgets('Empty credentials show validation without authenticating', (
    tester,
  ) async {
    var called = false;
    await openLogin(
      tester,
      LoginScreen(
        authenticate: ({required memberId, required password}) async {
          called = true;
          return true;
        },
      ),
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Please enter your Member ID.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('Malformed Member ID does not bypass authentication', (
    tester,
  ) async {
    var called = false;
    await openLogin(
      tester,
      LoginScreen(
        authenticate: ({required memberId, required password}) async {
          called = true;
          return true;
        },
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'anything');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'not-a-real-password',
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(called, isFalse);
    expect(find.byType(ConfirmPassScreen), findsNothing);
  });

  testWidgets('Rejected credentials show an error and stay on login', (
    tester,
  ) async {
    await openLogin(
      tester,
      LoginScreen(
        authenticate: ({required memberId, required password}) async {
          throw StateError('No account found or the password is incorrect.');
        },
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'CSUCC-2026-0007');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'not-a-real-password',
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(
      find.text('No account found or the password is incorrect.'),
      findsOneWidget,
    );
    expect(find.byType(ConfirmPassScreen), findsNothing);
  });

  testWidgets('Authenticated temporary-password user reaches password setup', (
    tester,
  ) async {
    var called = false;
    await openLogin(
      tester,
      LoginScreen(
        authenticate: ({required memberId, required password}) async {
          expect(memberId, 'CSUCC-2026-0007');
          called = true;
          return true;
        },
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'CSUCC-2026-0007');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'not-a-real-password',
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(find.byType(ConfirmPassScreen), findsOneWidget);
    expect(find.text('At least one lowercase letter'), findsOneWidget);
  });
}
