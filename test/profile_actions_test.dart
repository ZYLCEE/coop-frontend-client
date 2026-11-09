import 'package:coop_frontend/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('Profile actions explain availability at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsMenuCard())),
      );

      await tester.tap(find.text('Notification Preferences'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.text(
          'Notification preferences are currently unavailable in the app.',
        ),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      await tester.tap(find.text('Download Loan Statement'));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(
        find.text(
          'Loan statement downloads are currently unavailable in the app. '
          'Contact the cooperative office to request a statement.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(SettingsMenuCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
