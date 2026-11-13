import 'dart:convert';

import 'package:coop_frontend/loan_application_flow.dart';
import 'package:coop_frontend/loan_calculator_service.dart';
import 'package:coop_frontend/models/loan_agreement_snapshot.dart';
import 'package:coop_frontend/models/loan_application_draft.dart';
import 'package:coop_frontend/models/loan_policy.dart';
import 'package:coop_frontend/review_terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final supabase = await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        final payload = {
          'access_token': _testToken(),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'test-refresh-token',
          'user': {
            'id': 'test-member',
            'email': 'member@example.test',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
            'aud': 'authenticated',
            'created_at': '2020-01-01T00:00:00Z',
          },
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    client = supabase.client;
  });

  setUp(() async {
    await client.auth.signInWithPassword(
      email: 'member@example.test',
      password: 'synthetic-password',
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'review requires both confirmations and two different witness names',
    (tester) async {
      const policy = LoanPolicySettings(
        baseInterestRatePercent: 1.5,
        processingFeePercent: 1,
        serviceFeePercent: 0.5,
        minMemberTenureMonths: 6,
        minLoanAmount: 1000,
        maxLoanAmount: 500000,
        maxLoanMultiplier: 3,
        penaltyRatePercent: 2,
        coMakerRequiredAbove: 50000,
        collateralRequiredAbove: 200000,
        loanProcessingTime: '3-5',
      );
      final draft = LoanApplicationDraft(loanType: LoanType.regular)
        ..policy = policy;
      draft.computation = LoanCalculatorService().calculate(
        principal: draft.amount,
        months: draft.tenure,
        loanType: draft.loanType,
        baseInterestRatePercent: policy.baseInterestRatePercent,
        processingFeePercent: policy.processingFeePercent,
        serviceFeePercent: policy.serviceFeePercent,
      );
      final flow = LoanApplicationFlow(LoanType.regular, client);
      addTearDown(() => flow.close(removeRoutes: false));
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewTermsScreen(
            flow: flow,
            snapshot: LoanAgreementSnapshot.fromDraft(draft),
          ),
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

String _testToken() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return '${segment({'alg': 'HS256'})}.${segment({'exp': expiry})}.signature';
}
