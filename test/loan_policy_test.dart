import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/loan_calculator_service.dart';
import 'package:coop_frontend/models/loan_policy.dart';
import 'package:coop_frontend/email_otp_verification_screen.dart';

void main() {
  test(
    'OTP display masks the supplied Auth email instead of showing a placeholder',
    () {
      final masked = maskEmailAddress('mickmickengalan123@gmail.com');
      expect(masked, startsWith('m'));
      expect(masked, endsWith('@gmail.com'));
      expect(masked, isNot(contains('csucc.edu.ph')));
      expect(maskEmailAddress('not-an-email'), 'unavailable');
    },
  );
  testWidgets('OTP UI displays the real masked email and eight code boxes', (
    tester,
  ) async {
    final controllers = List.generate(8, (_) => TextEditingController());
    final focusNodes = List.generate(8, (_) => FocusNode());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              VerificationHeader(
                maskedEmail: maskEmailAddress('mickmickengalan123@gmail.com'),
                codeSent: true,
              ),
              OtpInputFields(
                controllers: controllers,
                focusNodes: focusNodes,
                onChanged: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.text(
        'An 8-digit verification code was sent to your registered email.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(maskEmailAddress('mickmickengalan123@gmail.com')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(8));
  });

  testWidgets('Verify OTP responds to input after the resend timer expires', (
    tester,
  ) async {
    final controllers = List.generate(8, (_) => TextEditingController());
    final focusNodes = List.generate(8, (_) => FocusNode());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    });

    var codeComplete = false;
    var verified = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                OtpInputFields(
                  controllers: controllers,
                  focusNodes: focusNodes,
                  onChanged: (_, _) {
                    setState(() {
                      codeComplete = controllers.every(
                        (controller) => controller.text.isNotEmpty,
                      );
                    });
                  },
                ),
                const OtpTimer(
                  remainingSeconds: 0,
                  canResend: true,
                  onResend: _ignoreResend,
                ),
                PrimaryButton(
                  isEnabled: codeComplete,
                  onPressed: () => verified = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    for (var index = 0; index < controllers.length; index++) {
      await tester.enterText(find.byType(TextField).at(index), '$index');
    }
    await tester.pump();

    final verifyButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verify OTP'),
    );
    expect(verifyButton.onPressed, isNotNull);
    await tester.tap(find.text('Verify OTP'));
    expect(verified, isTrue);
  });

  testWidgets('OTP input changes notify the verification screen immediately', (
    tester,
  ) async {
    final controllers = List.generate(8, (_) => TextEditingController());
    final focusNodes = List.generate(8, (_) => FocusNode());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    });

    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInputFields(
            controllers: controllers,
            focusNodes: focusNodes,
            onChanged: (_, _) => changes++,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '1');
    expect(changes, 1);
    expect(controllers.first.text, '1');
  });
  test(
    'Loan calculator applies the active policy interest and fee percentages',
    () {
      final result = LoanCalculatorService().calculate(
        principal: 10000,
        months: 10,
        loanType: LoanType.regular,
        baseInterestRatePercent: 2,
        processingFeePercent: 1.5,
        serviceFeePercent: 0.5,
      );
      expect(result.interestRate, 2);
      expect(result.totalInterest, 2000);
      expect(result.processingFee, 150);
      expect(result.retentionFee, 50);
    },
  );

  test(
    'Calculator preserves fractional policy rates for supported tenures',
    () {
      for (final months in [3, 6, 12, 24]) {
        final result = LoanCalculatorService().calculate(
          principal: 10000,
          months: months,
          loanType: LoanType.regular,
          baseInterestRatePercent: 1.55,
        );
        expect(result.totalInterest, closeTo(155 * months, 0.000001));
        expect(result.paymentDates, hasLength(months));
        expect(
          LoanCalculatorService.formatPercentage(result.interestRate),
          '1.55% / month flat',
        );
        expect(
          LoanCalculatorService.formatPercentage(
            result.interestRate,
            compact: true,
          ),
          '1.55%/mo',
        );
      }
      expect(LoanCalculatorService.formatPercentage(2), '2% / month flat');
    },
  );

  test('Policy settings deserialize numeric database values and metadata', () {
    final policy = LoanPolicySettings.fromMap({
      'base_interest_rate': '1.5',
      'processing_fee_percent': '1',
      'service_fee_percent': '0.5',
      'min_member_tenure_months': 6,
      'min_loan_amount': '1000',
      'max_loan_amount': '500000',
      'max_loan_multiplier': '3',
      'penalty_rate_percent': '2',
      'co_maker_required_above': '50000',
      'collateral_required_above': '200000',
      'loan_processing_time': '3–5',
    });
    expect(policy.minMemberTenureMonths, 6);
    expect(policy.maxLoanAmount, 500000);
    expect(policy.collateralRequiredAbove, 200000);
    expect(policy.loanProcessingTime, '3–5');
  });
}

void _ignoreResend() {}
