import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/review_terms_screen.dart';

void main() {
  testWidgets(
    'review requires both confirmations and two different witness names',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReviewTermsScreen(loanAmount: 50000, loanType: 'Regular'),
        ),
      );
      ElevatedButton button() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button().onPressed, isNull);
      for (var index = 0; index < 2; index++) {
        final finder = find.byType(Checkbox).at(index);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
      }
      expect(button().onPressed, isNull);
      final first = find.byKey(const Key('loan-witness-one'));
      final second = find.byKey(const Key('loan-witness-two'));
      await tester.ensureVisible(first);
      await tester.enterText(first, 'Witness One');
      await tester.ensureVisible(second);
      await tester.enterText(second, ' witness one ');
      await tester.pump();
      expect(button().onPressed, isNull);
      expect(find.text('Enter two different witnesses.'), findsOneWidget);
      await tester.enterText(second, 'Witness Two');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.enterText(first, '   ');
      await tester.pump();
      expect(button().onPressed, isNull);
    },
  );
}
