import 'dart:convert';
import 'dart:typed_data';

import 'package:coop_frontend/dashboard.dart';
import 'package:coop_frontend/bellicon.dart';
import 'package:coop_frontend/models/loan_submission_readiness.dart';
import 'package:coop_frontend/app_bottom_navigation_bar.dart';
import 'package:coop_frontend/documents_disbursement_screen.dart';
import 'package:coop_frontend/demo_loan_consent_screen.dart';
import 'package:coop_frontend/email_otp_verification_screen.dart';
import 'package:coop_frontend/loan_application_flow.dart';
import 'package:coop_frontend/loan_calculator_screen.dart';
import 'package:coop_frontend/member_information_card.dart';
import 'package:coop_frontend/loan_participants_screen.dart';
import 'package:coop_frontend/models/loan_participant.dart';
import 'package:coop_frontend/review_terms_screen.dart';
import 'package:coop_frontend/services/loan_participant_lookup.dart';
import 'package:coop_frontend/services/database_service.dart';
import 'package:coop_frontend/services/loan_document_upload_service.dart';
import 'package:coop_frontend/services/supabase_service.dart';
import 'package:coop_frontend/loan_calculator_service.dart';
import 'package:coop_frontend/loans_screen.dart';
import 'package:coop_frontend/models/loan_document.dart';
import 'package:coop_frontend/models/loan_consent_submission.dart';
import 'package:coop_frontend/models/loan_agreement_snapshot.dart';
import 'package:coop_frontend/models/loan_application_draft.dart';
import 'package:coop_frontend/models/loan_policy.dart';
import 'package:coop_frontend/widgets/loan_agreement_preview.dart';
import 'package:coop_frontend/profile_confirmation_screen.dart';
import 'package:coop_frontend/profile.dart';
import 'package:coop_frontend/widgets/loan_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
// Use the HTTP client type already used by Supabase.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  final requests = <http.Request>[];
  var loanRows = <Object>[];
  var loanHistoryUnavailable = false;
  var paymentRows = <Object>[];
  const email = 'member@example.test';
  const member = {
    'id': 'member-row',
    'member_id': 'MEM-001',
    'first_name': 'Test',
    'last_name': 'Borrower',
    'email': email,
    'date_of_birth': '1990-04-02',
    'institutional_email': 'example@csu.test',
    'date_joined': '2020-01-01',
  };
  const secondEmail = 'second@example.test';
  late Map<String, dynamic> profileRow;
  const policy = {
    'base_interest_rate': 1.5,
    'processing_fee_percent': 1,
    'service_fee_percent': 0.5,
    'min_member_tenure_months': 6,
    'min_loan_amount': 1000,
    'max_loan_amount': 500000,
    'max_loan_multiplier': 3,
    'penalty_rate_percent': 2,
    'co_maker_required_above': 50000,
    'collateral_required_above': 200000,
    'loan_processing_time': '3–5',
  };

  http.Response json(http.Request request, Object value, [int status = 200]) =>
      http.Response(
        jsonEncode(value),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Map<String, Object> session(String userEmail) {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    return {
      'access_token':
          '${segment({'alg': 'HS256'})}.${segment({'exp': exp})}.signature',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'fake-refresh-token',
      'user': {
        'id': userEmail,
        'email': userEmail,
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
        'aud': 'authenticated',
        'created_at': '2020-01-01T00:00:00Z',
      },
    };
  }

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
        requests.add(request);
        switch (request.url.path) {
          case '/auth/v1/token':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return json(request, session(body['email'] as String));
          case '/auth/v1/otp':
            return json(request, <String, Object>{});
          case '/auth/v1/verify':
            return json(request, {'message': 'Invalid test code'}, 400);
          case '/rest/v1/members':
            final userFilter = request.url.queryParameters['user_id'];
            if (userFilter == 'eq.$secondEmail') {
              return json(request, {
                'user_id': secondEmail,
                'first_name': 'Second',
                'last_name': 'Member',
              });
            }
            if (request.method != 'GET') {
              return json(request, {'message': 'Unexpected member write'}, 405);
            }
            return json(request, profileRow);
          case '/rest/v1/loan_applications':
            return loanHistoryUnavailable
                ? json(request, {'message': 'Test outage'}, 503)
                : json(request, loanRows);
          case '/rest/v1/loan_payments':
            return json(request, paymentRows);
          case '/rest/v1/loan_policy_settings':
            return json(request, policy);
          default:
            return json(request, {'message': 'Unexpected test request'}, 400);
        }
      }),
    );
    client = supabase.client;
  });

  setUp(() async {
    await client.auth.signInWithPassword(
      email: email,
      password: 'test-password',
    );
    requests.clear();
    profileRow = {...member, 'user_id': email};
    loanRows = [];
    loanHistoryUnavailable = false;
    paymentRows = [];
  });

  tearDownAll(() async => Supabase.instance.dispose());

  for (final width in [320.0, 360.0]) {
    testWidgets('Profile wraps long member details at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const longName = 'Alexandra Maria Dolores';
      final longAddress = List.filled(10, 'Long residential address').join(' ');
      profileRow.addAll({
        'first_name': longName,
        'membership_type': 'Regular',
        'department': 'Cooperative Member Support and Administration Office',
        'status': 'suspended',
        'phone': '09171234567',
        'address': longAddress,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final details = find.byType(PersonalInformationCard);
      for (final value in [
        '$longName Borrower',
        'MEM-001',
        'Regular',
        'Suspended',
        'Cooperative Member Support and Administration Office',
        '2020-01-01',
        '09171234567',
        email,
        longAddress,
      ]) {
        expect(
          find.descendant(of: details, matching: find.text(value)),
          findsOneWidget,
        );
      }
      expect(find.text('member-row'), findsNothing);
      expect(find.text('1990-04-02'), findsNothing);
      await tester.ensureVisible(
        find.text('Other member details are read only.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('visit the CSUCC cooperative office'),
        findsOneWidget,
      );
      expect(find.text('Edit Info'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      final requestCount = requests.length;
      await tester.ensureVisible(find.text('Edit Info'));
      await tester.tap(find.text('Edit Info'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(requestCount));
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Confirmation directs corrections to CSUCC and retains confirmed details',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileConfirmationScreen(loanType: LoanType.regular),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('registered member record'), findsOneWidget);
      expect(
        find.textContaining('visit the CSUCC cooperative office'),
        findsOneWidget,
      );
      expect(find.textContaining('You can edit'), findsOneWidget);

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tapText(tester, 'Proceed to Loan Calculator');
      await tester.pumpAndSettle();
      final calculator = tester.widget<LoanCalculatorScreen>(
        find.byType(LoanCalculatorScreen),
      );

      profileRow['first_name'] = 'Corrected';
      expect(calculator.flow.draft.profileConfirmed, isTrue);
      expect(calculator.flow.draft.applicant?['first_name'], 'Test');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Test Borrower'), findsOneWidget);
      expect(find.text('Corrected Borrower'), findsNothing);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    },
  );

  testWidgets(
    'Profile clears previous account and hides missing optional fields',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('MEM-001'), findsNWidgets(2));
      await client.auth.signInWithPassword(
        email: secondEmail,
        password: 'test-password',
      );
      await tester.pumpAndSettle();

      expect(find.text('MEM-001'), findsNothing);
      expect(find.text('Test Borrower'), findsNothing);
      expect(find.text('Second Member'), findsNWidgets(2));
      for (final label in [
        'MEMBER ID',
        'MEMBERSHIP TYPE',
        'DEPARTMENT',
        'MEMBERSHIP STATUS',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('Not available'), findsNWidgets(4));
      expect(
        requests
            .where((request) => request.url.path == '/rest/v1/members')
            .map((request) => request.url.queryParameters['user_id']),
        ['eq.$email', 'eq.$secondEmail'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> start(WidgetTester tester, {required bool dashboard}) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Dashboard()));
    await tester.pumpAndSettle();
    if (dashboard) {
      await tapText(tester, 'Apply for a Loan');
      expect(
        tester.widget<LoansScreen>(find.byType(LoansScreen)).hideTabs,
        true,
      );
    } else {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.byIcon(Icons.payments),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoansScreen>(find.byType(LoansScreen)).hideTabs,
        false,
      );
    }
    expect(find.text('Category 1 of 4'), findsOneWidget);
    await tester.ensureVisible(find.text('Apply Now').at(1));
    await tester.tap(find.text('Apply Now').at(1));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileConfirmationScreen), findsOneWidget);
    expect(
      find.text('Test Borrower'),
      findsOneWidget,
      reason: requests.map((r) => r.url.path).join(', '),
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tapText(tester, 'Proceed to Loan Calculator');
  }

  testWidgets(
    'Agreement preview captures revised draft values and wraps at 320 px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = LoanApplicationDraft(loanType: LoanType.emergency)
        ..applicant = Map.of(member)
        ..policy = LoanPolicySettings.fromMap(policy)
        ..applicationKind = LoanApplicationKind.renewal
        ..participants = (LoanParticipantsDraft()
          ..witnessOne = 'First witness'
          ..witnessTwo = 'Second witness');
      void recalculate() =>
          draft.computation = LoanCalculatorService().calculate(
            principal: draft.amount,
            months: draft.tenure,
            loanType: draft.loanType,
          );
      recalculate();
      final first = LoanAgreementSnapshot.fromDraft(draft);
      draft.amount = 65000;
      draft.tenure = 24;
      draft.participants!.witnessOne = 'Updated witness';
      recalculate();
      final revised = LoanAgreementSnapshot.fromDraft(draft);
      expect(first.amount, 50000);
      expect(first.witnessOne, 'First witness');
      expect(revised.applicant, first.applicant);
      expect(revised.computation.principal, 65000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LoanAgreementPreview(snapshot: revised),
            ),
          ),
        ),
      );
      expect(find.text('Requested amount: ₱65000.00'), findsOneWidget);
      expect(find.text('Repayment tenure: 24 months'), findsOneWidget);
      expect(find.text('Renewal (draft only)'), findsOneWidget);
      expect(find.text('Updated witness'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Demo amount changes update document controls and summary', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final flow = LoanApplicationFlow(
      LoanType.regular,
      client,
      participantsDemo: true,
    );
    addTearDown(() => flow.close(removeRoutes: false));
    final draft = flow.draft
      ..applicant = member
      ..profileConfirmed = true
      ..participants = (LoanParticipantsDraft()
        ..coMakerNameInput = 'Demo Member Two'
        ..coMaker = const LoanCoMakerCandidate(
          memberId: '2099-9002',
          name: 'Demo Member Two',
          isDemo: true,
        )
        ..relationship = 'Colleague');
    SelectedLoanDocument file(LoanDocumentKind kind) =>
        SelectedLoanDocument.fromBytes(
          kind: kind,
          name: '${kind.name}.pdf',
          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        );
    for (final kind in [
      LoanDocumentKind.payslip,
      LoanDocumentKind.validId,
      LoanDocumentKind.supporting,
    ]) {
      draft.documents[kind] = file(kind);
    }
    await tester.pumpWidget(
      MaterialApp(home: LoanCalculatorScreen(flow: flow)),
    );
    await tester.pumpAndSettle();

    Future<void> openDocuments(String amount, double width) async {
      final input = find.descendant(
        of: find.byType(LoanAmountSlider),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(input);
      await tester.enterText(input, '');
      await tester.enterText(input, amount);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(draft.amount, double.parse(amount));
      await tapText(tester, 'Continue to Participants');
      expect(find.text('Demo Member Two'), findsOneWidget);
      await selectRelationship(tester, 'Colleague');
      await enterParticipantField(tester, 'Witness 1', 'Demo Witness One');
      await enterParticipantField(tester, 'Witness 2', 'Demo Witness Two');
      await tapText(tester, 'Continue to Documents');
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> backToDetails() async {
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    }

    final review = find.widgetWithText(ElevatedButton, 'Continue to Review');
    await openDocuments('199999.99', 320);
    expect(find.text('Collateral Document'), findsNothing);
    expect(find.text('Pay Slip *'), findsOneWidget);
    expect(find.text('Valid Identification *'), findsOneWidget);
    expect(find.text('Other Supporting Documents'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(review).onPressed, isNotNull);
    await backToDetails();

    await openDocuments('200000', 360);
    expect(find.text('Collateral Document'), findsOneWidget);
    expect(find.text('Required in demo'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(review).onPressed, isNull);
    draft.documents[LoanDocumentKind.collateral] = file(
      LoanDocumentKind.collateral,
    );
    await backToDetails();

    await openDocuments('200000.01', 320);
    expect(find.text('collateral.pdf'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue to Review');
    expect(find.text('Collateral Document · Required in demo'), findsOneWidget);
    expect(
      find.textContaining('collateral.pdf (PDF) · Selected locally'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await backToDetails();

    await openDocuments('150000', 360);
    expect(find.text('collateral.pdf'), findsNothing);
    expect(find.textContaining('excluded from review'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue to Review');
    expect(find.textContaining('Collateral Document'), findsNothing);
    expect(find.textContaining('collateral.pdf'), findsNothing);
    for (final kind in [
      LoanDocumentKind.payslip,
      LoanDocumentKind.validId,
      LoanDocumentKind.supporting,
    ]) {
      expect(
        find.textContaining('${kind.name}.pdf (PDF) · Selected locally'),
        findsOneWidget,
      );
    }
    expect(requests.every((request) => request.method == 'GET'), isTrue);
  });

  testWidgets(
    'Participant demo retains selections and isolates simulated consent',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final flow = LoanApplicationFlow(
        LoanType.emergency,
        client,
        participantsDemo: true,
      );
      addTearDown(() => flow.close(removeRoutes: false));
      final draft = flow.draft;
      draft.applicant = {...member, 'member_id': 'CSUCC-2099-9003'};
      draft.profileConfirmed = true;
      draft.amount = 60000;
      draft.tenure = 6;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    flow.push(context, (_) => LoanCalculatorScreen(flow: flow)),
                child: const Text('Open demo'),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, 'Open demo');
      await tapText(tester, 'Continue to Participants');
      final participants = find.byType(LoanParticipantsScreen);
      expect(participants, findsOneWidget);
      expect(
        tester
            .widget<LoanProgressIndicator>(find.byType(LoanProgressIndicator))
            .currentStep,
        1,
      );

      await tapText(tester, 'Continue to Documents');
      expect(find.text('Look up and select a demo co-maker.'), findsOneWidget);
      await enterParticipantField(tester, 'Co-Maker Member Name', 'invalid');
      await tapText(tester, 'Look Up Demo Member');
      expect(find.textContaining('first and last name'), findsOneWidget);
      await enterParticipantField(tester, 'Co-Maker Member Name', 'Demo Member Three');
      await tapText(tester, 'Look Up Demo Member');
      expect(
        find.text('Choose a co-maker other than yourself.'),
        findsOneWidget,
      );
      await enterParticipantField(tester, 'Co-Maker Member Name', 'Unknown Member');
      await tapText(tester, 'Look Up Demo Member');
      expect(find.textContaining('Demo member not found'), findsOneWidget);
      await enterParticipantField(tester, 'Co-Maker Member Name', 'Demo Member Two');
      await tapText(tester, 'Look Up Demo Member');
      expect(find.text('Demo Member Two'), findsOneWidget);
      expect(find.textContaining('Fictional demo record'), findsOneWidget);
      await selectRelationship(tester, 'Colleague');
      await enterParticipantField(tester, 'Witness 1', 'Demo Witness A');
      await enterParticipantField(tester, 'Witness 2', 'demo witness a');
      expect(
        find.textContaining('Both witness slots have the same name'),
        findsOneWidget,
      );
      await enterParticipantField(tester, 'Witness 2', 'Demo Witness B');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Continue to Documents');

      Navigator.of(
        tester.element(find.byType(DocumentsDisbursementScreen)),
      ).pop();
      await tester.pumpAndSettle();
      expect(draft.amount, 60000);
      expect(draft.tenure, 6);
      expect(find.byType(LoanParticipantsScreen), findsOneWidget);
      expect(find.text('Demo Member Two'), findsOneWidget);
      expect(find.text('Colleague'), findsOneWidget);
      expect(find.text('Demo Witness A'), findsOneWidget);
      expect(find.text('Demo Witness B'), findsOneWidget);

      for (final kind in [LoanDocumentKind.payslip, LoanDocumentKind.validId]) {
        draft.documents[kind] = SelectedLoanDocument.fromBytes(
          kind: kind,
          name: '${kind.name}.pdf',
          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        );
      }
      await tapText(tester, 'Continue to Documents');
      final documents = find.byType(DocumentsDisbursementScreen);
      expect(documents, findsOneWidget);
      expect(
        tester
            .widget<LoanProgressIndicator>(find.byType(LoanProgressIndicator))
            .currentStep,
        2,
      );
      Navigator.of(tester.element(documents)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Demo Member Two'), findsOneWidget);
      await tapText(tester, 'Continue to Documents');
      await tapText(tester, 'Continue to Review');
      expect(
        tester
            .widget<LoanProgressIndicator>(find.byType(LoanProgressIndicator))
            .currentStep,
        3,
      );
      expect(find.text('Relationship to borrower: Colleague'), findsOneWidget);
      expect(find.text('Witness 1'), findsOneWidget);
      expect(find.text('Witness 2'), findsOneWidget);
      expect(find.text('Demo Witness A'), findsOneWidget);
      expect(find.text('Demo Witness B'), findsOneWidget);
      expect(find.text('payslip.pdf (PDF) · Selected locally'), findsOneWidget);
      expect(find.text('Uploaded'), findsNothing);
      await tapText(tester, 'Preview Agreement and Terms');
      expect(find.text('Requested amount: ₱60000.00'), findsOneWidget);
      expect(find.text('Repayment tenure: 6 months'), findsOneWidget);
      expect(find.text('Employer Certification'), findsOneWidget);
      expect(find.text('Agreement and Promissory Note'), findsOneWidget);
      expect(find.text('Local demo revision 1'), findsOneWidget);
      expect(find.text('Co-Maker Request'), findsNothing);
      expect(find.text('Send OTP to Continue'), findsNothing);
      expect(demoButton(tester, 'Continue to Verification').onPressed, isNull);
      await acknowledge(tester);
      await tapText(tester, 'Continue to Verification');
      expect(find.text('Borrower Demo Verification'), findsOneWidget);
      expect(demoButton(tester, 'Verify Demo Code').onPressed, isNull);
      await enterDemoCode(tester, '87654321');
      expect(find.text('Incorrect demo code. Try again.'), findsOneWidget);
      await tapText(tester, 'Restart Demo Challenge');
      expect(demoButton(tester, 'Verify Demo Code').onPressed, isNull);
      await enterDemoCode(tester, '12345678', repeatTap: true);
      expect(find.text('Borrower: Demo Confirmed'), findsOneWidget);
      expect(find.text('Co-Maker: Awaiting Response'), findsOneWidget);
      expect(find.text('Co-Maker Request'), findsNothing);
      expect(find.text('Open Co-Maker Perspective'), findsNothing);
      await tapText(tester, 'Open Fictional Co-Maker Inbox');
      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(
          find.text('Fictional recipient: Demo Member Two'),
          findsOneWidget,
        );
        expect(find.text('Co-Maker Request'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.textContaining('Test Borrower'), findsNothing);
        expect(find.textContaining('payslip.pdf'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pumpAndSettle();
      await tapText(tester, 'Review Request');
      expect(find.byType(ParticipantAgreementReviewScreen), findsOneWidget);
      expect(find.text('Local demo revision 1'), findsOneWidget);
      expect(find.text('Borrower: Demo Borrower'), findsOneWidget);
      expect(find.text('Borrower: Test Borrower'), findsNothing);
      expect(find.textContaining('payslip.pdf'), findsNothing);
      expect(find.textContaining('Demo Witness A'), findsNothing);
      expect(find.text('Requested amount: ₱60000.00'), findsOneWidget);
      expect(find.text('Repayment tenure: 6 months'), findsOneWidget);
      expect(find.text('Total estimated interest: ₱5400.00'), findsOneWidget);
      expect(find.text('Processing fee: ₱600.00'), findsOneWidget);
      expect(find.text('Total estimated repayment: ₱65400.00'), findsOneWidget);
      expect(find.textContaining('Installment 6'), findsOneWidget);
      expect(find.textContaining('Approved wording'), findsOneWidget);
      expect(
        find.textContaining('joint and several liability'),
        findsOneWidget,
      );
      expect(demoButton(tester, 'Continue to Consent').onPressed, isNull);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Decline Request'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tapText(tester, 'Decline Request');
      expect(find.text('Decline this demo request?'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(find.text('Decline Request'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Read'), findsOneWidget);
      await tapText(tester, 'Review Request');
      await tapText(tester, 'Decline Request');
      await tapText(tester, 'Confirm Decline');
      expect(find.text('Co-Maker Declined'), findsOneWidget);
      expect(find.text('Continue to Consent'), findsNothing);
      await tapText(tester, 'Back to Fictional Inbox');
      expect(find.textContaining('Co-Maker Declined'), findsOneWidget);
      expect(find.text('Review Request'), findsNothing);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.physicalSize = const Size(800, 1000);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Co-Maker: Declined'), findsOneWidget);
      expect(find.text('Demo Incomplete – Not Submitted'), findsOneWidget);
      expect(find.text('Co-Maker Request'), findsNothing);

      final navigator = Navigator.of(
        tester.element(find.byType(ReviewTermsScreen)),
      );
      navigator.pop();
      await tester.pumpAndSettle();
      await tapText(tester, 'Preview Agreement and Terms');
      expect(find.text('Local demo revision 2'), findsOneWidget);
      expect(find.text('Co-Maker: Declined'), findsOneWidget);
      expect(find.text('Continue to Verification'), findsNothing);
      expect(find.text('Co-Maker Request'), findsNothing);
      for (var route = 0; route < 3; route++) {
        navigator.pop();
        await tester.pumpAndSettle();
      }
      expect(participants, findsOneWidget);
      expect(draft.amount, 60000);
      expect(draft.documents, hasLength(2));
      await enterParticipantField(tester, 'Co-Maker Member Name', 'Demo Member One');
      await tapText(tester, 'Look Up Demo Member');
      await selectRelationship(tester, 'Friend');
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '65000');
      await tester.pumpAndSettle();
      await tapText(tester, 'Continue to Participants');
      await tapText(tester, 'Continue to Documents');
      await tapText(tester, 'Continue to Review');
      await tapText(tester, 'Preview Agreement and Terms');
      expect(find.text('Local demo revision 3'), findsOneWidget);
      expect(find.text('Requested amount: ₱65000.00'), findsOneWidget);
      expect(find.text('Co-Maker Request'), findsNothing);
      expect(find.text('Co-Maker: Declined'), findsNothing);
      await acknowledge(tester);
      await tapText(tester, 'Continue to Verification');
      await enterDemoCode(tester, '12345678');
      await tapText(tester, 'Open Fictional Co-Maker Inbox');
      expect(find.text('Fictional recipient: Demo Member One'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      await tapText(tester, 'Review Request');
      expect(find.text('Local demo revision 3'), findsOneWidget);
      await acknowledge(tester);
      await tapText(tester, 'Continue to Consent');
      expect(find.text('Co-Maker Demo Verification'), findsOneWidget);
      expect(find.text('Fictional co-maker: Demo Member One'), findsOneWidget);
      expect(demoButton(tester, 'Verify Demo Code').onPressed, isNull);
      await enterDemoCode(tester, '87654321');
      expect(find.text('Incorrect demo code. Try again.'), findsOneWidget);
      await tapText(tester, 'Restart Demo Challenge');
      await enterDemoCode(tester, '12345678', repeatTap: true);
      expect(find.text('Co-Maker Demo Consent Recorded'), findsOneWidget);
      await tapText(tester, 'Back to Fictional Inbox');
      expect(
        find.textContaining('Co-Maker Demo Consent Recorded'),
        findsOneWidget,
      );
      expect(find.text('Review Request'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Co-Maker: Demo Consent Recorded'), findsOneWidget);
      expect(find.text('Application Readiness'), findsOneWidget);
      expect(find.text('Application Preview Completed'), findsOneWidget);
      expect(find.text('Applicant information: Complete'), findsOneWidget);
      expect(find.text('Documents: Selected Locally'), findsOneWidget);
      expect(
        find.text('Witness 1: Pending Cooperative Confirmation'),
        findsOneWidget,
      );
      expect(
        find.text('Witness 2: Pending Cooperative Confirmation'),
        findsOneWidget,
      );
      expect(
        find.text('Employer Certification: Pending Cooperative Confirmation'),
        findsOneWidget,
      );
      expect(
        find.text('Notarial acknowledgment: Pending Cooperative Confirmation'),
        findsOneWidget,
      );
      expect(
        find.text('Application submission: Not Available in Demo'),
        findsOneWidget,
      );
      expect(find.text('Application Submitted'), findsNothing);
      await tapText(tester, 'Return to Agreement Preview');
      expect(find.text('Co-Maker: Demo Consent Recorded'), findsOneWidget);
      // A direct attempt to open the existing OTP screen must also fail closed.
      flow.push(
        tester.element(find.byType(ReviewTermsScreen)),
        (_) => EmailOtpVerificationScreen(flow: flow),
      );
      await tester.pumpAndSettle();
      expect(find.text('End of participant selection demo.'), findsOneWidget);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);

      await client.auth.signInWithPassword(
        email: 'other@example.test',
        password: 'test-password',
      );
      await tester.pumpAndSettle();
      expect(flow.isActive, false);
      expect(draft.participants, isNull);
      expect(find.text('Open demo'), findsOneWidget);
    },
  );

  testWidgets(
    'Demo requests are revision-bound and absent from member notifications',
    (tester) async {
      final flow = LoanApplicationFlow(
        LoanType.regular,
        client,
        participantsDemo: true,
      );
      addTearDown(() => flow.close(removeRoutes: false));
      const one = LoanCoMakerCandidate(
        memberId: 'CSUCC-2099-9001',
        name: 'Demo Member One',
      );
      const two = LoanCoMakerCandidate(
        memberId: 'CSUCC-2099-9002',
        name: 'Demo Member Two',
      );
      final draft = flow.draft
        ..policy = LoanPolicySettings.fromMap(policy)
        ..computation = LoanCalculatorService().calculate(
          principal: 50000,
          months: 12,
          loanType: LoanType.regular,
        )
        ..participants = (LoanParticipantsDraft()..coMaker = one);
      final first = LoanAgreementSnapshot.fromDraft(
        draft,
        participantsDemo: true,
      );
      final rev1 = flow.beginConsentDemoReview(first)!;
      expect(flow.demoRequestFor(rev1, one.memberId), isNull);
      final request = flow.recordDemoBorrowerConfirmation(rev1, first)!;
      expect(flow.recordDemoBorrowerConfirmation(rev1, first), same(request));
      expect(flow.demoRequestFor(rev1, two.memberId), isNull);
      expect(flow.demoRequestFor(rev1, one.memberId), same(request));
      expect(request.isRead, isFalse);

      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Co-Maker Request'), findsNothing);
      expect(requests.every((request) => request.method == 'GET'), isTrue);

      final revised = LoanAgreementSnapshot.fromDraft(
        draft,
        participantsDemo: true,
      );
      final rev2 = flow.beginConsentDemoReview(revised)!;
      expect(flow.markDemoRequestRead(request), isFalse);
      expect(flow.recordDemoBorrowerConfirmation(rev2, first), isNull);
      final second = flow.recordDemoBorrowerConfirmation(rev2, revised)!;
      draft.participants!.coMaker = two;
      expect(flow.demoRequestFor(rev2, one.memberId), isNull);
      expect(
        flow.resolveDemoRequest(second, DemoCoMakerDecision.confirmed),
        isFalse,
      );

      final replacement = LoanAgreementSnapshot.fromDraft(
        draft,
        participantsDemo: true,
      );
      final rev3 = flow.beginConsentDemoReview(replacement)!;
      final third = flow.recordDemoBorrowerConfirmation(rev3, replacement)!;
      expect(
        flow.resolveDemoRequest(third, DemoCoMakerDecision.declined),
        isTrue,
      );
      expect(
        flow.resolveDemoRequest(third, DemoCoMakerDecision.confirmed),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));

      await client.auth.signInWithPassword(
        email: secondEmail,
        password: 'test-password',
      );
      await tester.pumpAndSettle();
      expect(flow.demoRequestFor(rev3, two.memberId), isNull);
      expect(flow.markDemoRequestRead(third), isFalse);
      expect(
        requests
            .where((request) => request.method != 'GET')
            .map((request) => request.url.path),
        ['/auth/v1/token'],
      );
    },
  );

  test(
    'Material draft changes invalidate requests and recorded demo consent',
    () {
      final flow = LoanApplicationFlow(
        LoanType.regular,
        client,
        participantsDemo: true,
      );
      addTearDown(() => flow.close(removeRoutes: false));
      final draft = flow.draft
        ..policy = LoanPolicySettings.fromMap(policy)
        ..participants = (LoanParticipantsDraft()
          ..coMaker = const LoanCoMakerCandidate(
            memberId: 'CSUCC-2099-9001',
            name: 'Demo Member One',
          ));
      LoanComputation calculate() => LoanCalculatorService().calculate(
        principal: draft.amount,
        months: draft.tenure,
        loanType: draft.loanType,
      );
      DemoCoMakerRequest issue() {
        draft.computation = calculate();
        final snapshot = LoanAgreementSnapshot.fromDraft(
          draft,
          participantsDemo: true,
        );
        return flow.recordDemoBorrowerConfirmation(
          flow.beginConsentDemoReview(snapshot)!,
          snapshot,
        )!;
      }

      for (final change in <void Function()>[
        () => draft.amount += 1000,
        () => draft.loanType = LoanType.emergency,
        () => draft.tenure = 6,
        () => draft.computation = calculate(),
        () => draft.computation!.paymentDates.removeLast(),
      ]) {
        final request = issue();
        expect(flow.canRespondToDemoRequest(request), isTrue);
        change();
        expect(flow.canRespondToDemoRequest(request), isFalse);
        expect(
          flow.resolveDemoRequest(request, DemoCoMakerDecision.confirmed),
          isFalse,
        );
      }

      final confirmed = issue();
      expect(
        flow.resolveDemoRequest(confirmed, DemoCoMakerDecision.confirmed),
        isTrue,
      );
      expect(
        flow.resolveDemoRequest(confirmed, DemoCoMakerDecision.confirmed),
        isFalse,
      );
      draft.participants!.coMaker = const LoanCoMakerCandidate(
        memberId: 'CSUCC-2099-9002',
        name: 'Demo Member Two',
      );
      expect(
        flow.demoRequestFor(confirmed.revision, confirmed.recipient.memberId),
        isNull,
      );
      final replacement = issue();
      expect(replacement.decision, DemoCoMakerDecision.pending);
      flow.close(removeRoutes: false);
      expect(flow.canRespondToDemoRequest(replacement), isFalse);
      expect(requests, isEmpty);
    },
  );

  testWidgets('Changing the draft during co-maker OTP prevents consent', (
    tester,
  ) async {
    final flow = LoanApplicationFlow(
      LoanType.regular,
      client,
      participantsDemo: true,
    );
    addTearDown(() => flow.close(removeRoutes: false));
    final draft = flow.draft
      ..applicant = member
      ..policy = LoanPolicySettings.fromMap(policy)
      ..computation = LoanCalculatorService().calculate(
        principal: 50000,
        months: 12,
        loanType: LoanType.regular,
      )
      ..participants = (LoanParticipantsDraft()
        ..coMaker = const LoanCoMakerCandidate(
          memberId: 'CSUCC-2099-9001',
          name: 'Demo Member One',
        ));
    await tester.pumpWidget(
      MaterialApp(
        home: DemoLoanConsentScreen(
          flow: flow,
          snapshot: LoanAgreementSnapshot.fromDraft(
            draft,
            participantsDemo: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await acknowledge(tester);
    await tapText(tester, 'Continue to Verification');
    await enterDemoCode(tester, '12345678');
    await tapText(tester, 'Open Fictional Co-Maker Inbox');
    await tapText(tester, 'Review Request');
    await acknowledge(tester);
    await tapText(tester, 'Continue to Consent');
    expect(find.text('Co-Maker Demo Verification'), findsOneWidget);
    final input = find.byType(TextField);
    await tester.ensureVisible(input);
    await tester.enterText(input, '12345678');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Verify Demo Code'));
    await tester.tap(find.text('Verify Demo Code'));
    await tester.pump();
    draft.amount += 1000;
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Demo Verification Unavailable'), findsOneWidget);
    expect(find.text('Co-Maker Demo Consent Recorded'), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('Demo verification is usable at 320 pixels', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = LoanApplicationFlow(
      LoanType.regular,
      client,
      participantsDemo: true,
    );
    addTearDown(() => flow.close(removeRoutes: false));
    final draft = flow.draft
      ..applicant = Map.of(member)
      ..policy = LoanPolicySettings.fromMap(policy)
      ..computation = LoanCalculatorService().calculate(
        principal: 50000,
        months: 12,
        loanType: LoanType.regular,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DemoLoanConsentScreen(
          flow: flow,
          snapshot: LoanAgreementSnapshot.fromDraft(draft),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await acknowledge(tester);
    await tapText(tester, 'Continue to Verification');
    await enterDemoCode(tester, '12345678');
    expect(find.text('Borrower: Demo Confirmed'), findsOneWidget);
    expect(find.text('Co-Maker Request'), findsNothing);
    await tapText(tester, 'View Application Readiness');
    expect(find.text('Application Preview In Progress'), findsOneWidget);
    expect(
      find.text('Application submission: Not Available in Demo'),
      findsOneWidget,
    );
    await tapText(tester, 'Return to Agreement Preview');
    expect(tester.takeException(), isNull);
    expect(requests, isEmpty);
  });

  test(
    'Live OTP and submission services reject direct demo calls before I/O',
    () async {
      final auth = SupabaseService();
      await expectLater(
        auth.sendOtp(email: email, participantsDemo: true),
        throwsStateError,
      );
      await expectLater(
        auth.verifyOtp(email: email, token: '12345678', participantsDemo: true),
        throwsStateError,
      );
      await expectLater(
        DatabaseService().submitLoanApplication(
          applicationId: 'blocked-demo',
          loanType: 'Regular Loan',
          amount: 50000,
          documents: const [],
          tenureMonths: 12,
          consent: const LoanConsentSubmission(
            termsAccepted: true,
            informationCertified: true,
          ),
          participantsDemo: true,
        ),
        throwsStateError,
      );
      await expectLater(
        LoanDocumentUploadService(client: client).submit(
          applicationId: 'blocked-demo',
          loanType: 'Regular Loan',
          amount: 50000,
          documents: const [],
          tenureMonths: 12,
          consent: const LoanConsentSubmission(
            termsAccepted: true,
            informationCertified: true,
          ),
          participantsDemo: true,
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);
    },
  );

  testWidgets('Unavailable participant lookup gives a retryable error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = LoanApplicationFlow(
      LoanType.regular,
      client,
      participantsDemo: true,
    );
    addTearDown(() => flow.close(removeRoutes: false));
    await tester.pumpWidget(
      MaterialApp(
        home: LoanParticipantsScreen(flow: flow, lookup: _FailingLookup()),
      ),
    );
    await enterParticipantField(tester, 'Co-Maker Member Name', 'Demo Member Two');
    await tapText(tester, 'Look Up Demo Member');
    expect(
      find.text('Demo member lookup is unavailable. Try again.'),
      findsOneWidget,
    );
    expect(flow.draft.participants?.coMaker, isNull);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Dashboard activity matches Quick Actions with and without payments',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Rect card(String heading) {
        final container = tester
            .element(find.text(heading))
            .findAncestorWidgetOfExactType<Container>()!;
        return tester.getRect(find.byWidget(container));
      }

      for (final hasPayments in [false, true]) {
        if (hasPayments) {
          loanRows = [
            {'id': 'loan-test', 'status': 'released', 'loan_type': 'Regular'},
          ];
          paymentRows = [
            {
              'loan_application_id': 'loan-test',
              'payment_amount': 250,
              'payment_date': '2026-10-29',
            },
          ];
        }
        await tester.pumpWidget(
          MaterialApp(home: Dashboard(key: ValueKey(hasPayments))),
        );
        await tester.pumpAndSettle();
        final quickActions = card('QUICK ACTIONS');
        final recent = card('RECENT ACTIVITY');
        expect(recent.left, quickActions.left);
        expect(recent.right, quickActions.right);
        expect(
          find.text('No recent activity yet.'),
          hasPayments ? findsNothing : findsOneWidget,
        );
        expect(
          find.textContaining('Loan Payment'),
          hasPayments ? findsOneWidget : findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Member information fills both parent alignments with long text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const cardKey = ValueKey('member-card');
    for (final (width, alignment) in [
      (320.0, CrossAxisAlignment.center),
      (360.0, CrossAxisAlignment.start),
    ]) {
      tester.view.physicalSize = Size(width, 780);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: alignment,
                    children: [
                      const SizedBox(width: double.infinity),
                      LiveMemberInformationCard(
                        key: cardKey,
                        snapshot: {
                          ...member,
                          'first_name': 'A long compound applicant name',
                          'institutional_email':
                              'extended.cooperative.member.address@example.test',
                          'address':
                              'A long residential address with a district and city',
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(cardKey)).left, 16);
      expect(tester.getSize(find.byKey(cardKey)).width, width - 32);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Progress fits a narrow layout and shows only existing stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Center(
          child: SizedBox(
            width: 280,
            child: LoanProgressIndicator(currentStep: 1),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
      ),
    );
    expect(find.text('Loan Details'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Participants'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Available Loans pages by swipe or buttons and preserves restrictions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      loanRows = [
        {
          'id': 'educational-loan',
          'status': 'released',
          'loan_type': 'Educational',
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: const LoansScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      TextButton control(String label) =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, label));

      expect(find.text('Category 1 of 4'), findsOneWidget);
      expect(find.text('Personal Loans'), findsOneWidget);
      expect(find.text('Regular Loan'), findsWidgets);
      expect(find.text('Educational Loan'), findsNothing);
      expect(control('Previous').onPressed, isNull);
      await tester.drag(find.byType(PageView), const Offset(-285, 0));
      await tester.pumpAndSettle();
      expect(find.text('Category 2 of 4'), findsOneWidget);
      expect(find.text('Special Purpose Loans'), findsOneWidget);
      expect(find.text('Educational Loan'), findsWidgets);
      expect(find.text('Regular Loan'), findsNothing);
      expect(find.text('Loan Active'), findsOneWidget);
      expect(find.text('Apply Now'), findsNWidgets(3));

      await tester.drag(find.byType(PageView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(find.text('Category 2 of 4'), findsOneWidget);
      expect(find.byType(ProfileConfirmationScreen), findsNothing);

      await tapText(tester, 'Next');
      expect(find.text('Category 3 of 4'), findsOneWidget);
      await tapText(tester, 'Next');
      expect(find.text('Category 4 of 4'), findsOneWidget);
      expect(find.text('Secured & Other Loans'), findsOneWidget);
      expect(control('Next').onPressed, isNull);
      await tapText(tester, 'Previous');
      expect(find.text('Category 3 of 4'), findsOneWidget);
      await tapText(tester, 'My Loans');
      await tapText(tester, 'Available Loans');
      expect(find.text('Category 3 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'Dashboard actions align and track empty history at ${width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: const Dashboard(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final apply = find.widgetWithText(ElevatedButton, 'Apply for a Loan');
        final track = find.widgetWithText(ElevatedButton, 'Track Application');
        expect(apply, findsOneWidget);
        expect(track, findsOneWidget);
        expect(find.textContaining('Contributions'), findsNothing);
        expect(find.textContaining('Ledgers'), findsNothing);
        expect(tester.getRect(apply).left, tester.getRect(track).left);
        expect(tester.getRect(apply).right, tester.getRect(track).right);
        expect(
          tester.getRect(apply).bottom,
          lessThan(tester.getRect(track).top),
        );

        await tapText(tester, 'Track Application');
        expect(find.byType(LoansScreen), findsOneWidget);
        expect(find.text('My Loans'), findsOneWidget);
        expect(find.text('Category 1 of 4'), findsNothing);
        expect(find.text('No loans found'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(Dashboard), findsOneWidget);
        expect(find.byType(LoansScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Track Application shows only pending records and opens the selected status',
    (tester) async {
      loanRows = [
        {
          'id': 'pending-row',
          'application_id': 'APP-PENDING',
          'loan_type': 'Regular',
          'date_submitted': '2026-11-01',
          'status': 'pending',
          'amount': 5000,
        },
        {
          'id': 'review-row',
          'application_id': 'APP-REVIEW',
          'loan_type': 'Educational',
          'date_submitted': '2026-11-02',
          'status': 'under review',
          'amount': 7000,
        },
      ];
      await tester.pumpWidget(const MaterialApp(home: Dashboard()));
      await tester.pumpAndSettle();
      final apply = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Application Pending'),
      );
      expect(apply.onPressed, isNull);
      final readsBeforeTracking = requests
          .where((request) => request.url.path == '/rest/v1/loan_applications')
          .length;
      await tapText(tester, 'Track Application');
      expect(find.text('APP-PENDING\n2026-11-01'), findsOneWidget);
      expect(find.text('APP-REVIEW\n2026-11-02'), findsOneWidget);
      await tapText(tester, 'APP-PENDING\n2026-11-01');
      expect(find.text('Application ID: APP-PENDING'), findsOneWidget);
      expect(find.text('Status: Pending'), findsOneWidget);
      expect(find.textContaining('Credit Committee'), findsNothing);
      await tapText(tester, 'Close');

      await tapText(tester, 'APP-REVIEW\n2026-11-02');
      expect(find.text('Status: Under Review'), findsOneWidget);
      final loanRequests = requests
          .where((request) => request.url.path == '/rest/v1/loan_applications')
          .toList();
      expect(loanRequests.length, readsBeforeTracking + 1);
      expect(
        loanRequests.last.url.queryParameters['member_id'],
        'eq.member-row',
      );
      expect(loanRequests.every((request) => request.method == 'GET'), isTrue);
    },
  );

  testWidgets(
    'Track Application shows retrieval errors and retries pending history',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Dashboard()));
      await tester.pumpAndSettle();
      loanHistoryUnavailable = true;
      await tapText(tester, 'Track Application');
      expect(
        find.text(
          'Could not read loan records for your member account. Check the loan table access and retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('No loans found'), findsNothing);
      loanHistoryUnavailable = false;
      await tapText(tester, 'Retry');
      expect(find.text('No loans found'), findsOneWidget);
      expect(find.text('Loan History'), findsOneWidget);
    },
  );

  for (final fromDashboard in [true, false]) {
    testWidgets(
      'Catalog aligns Apply Now from ${fromDashboard ? 'Dashboard' : 'Loans'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final scale = ValueNotifier(1.0);
        addTearDown(scale.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: const Dashboard(),
            builder: (context, child) => ValueListenableBuilder<double>(
              valueListenable: scale,
              child: child,
              builder: (context, value, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(value)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (fromDashboard) {
          await tapText(tester, 'Apply for a Loan');
        } else {
          await tester.tap(
            find.descendant(
              of: find.byType(AppBottomNavigationBar),
              matching: find.byIcon(Icons.payments),
            ),
          );
          await tester.pumpAndSettle();
        }

        for (final width in [800.0, 320.0, 360.0]) {
          tester.view.physicalSize = Size(width, 1000);
          scale.value = width == 800 ? 1 : 1.5;
          await tester.pumpAndSettle();
          final button = find.widgetWithText(ElevatedButton, 'Apply Now').first;
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final footer = find
              .ancestor(
                of: button,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.padding != null &&
                      widget.decoration ==
                          const BoxDecoration(color: Colors.white),
                ),
              )
              .first;
          final bounds = tester.getRect(footer);
          final padding = tester
              .widget<Container>(footer)
              .padding!
              .resolve(TextDirection.ltr);
          final title = find.descendant(
            of: footer,
            matching: find.text('Regular Loan'),
          );
          expect(
            tester.getTopLeft(title).dx,
            closeTo(bounds.left + padding.left, 0.01),
          );
          expect(
            tester.getTopRight(button).dx,
            closeTo(bounds.right - padding.right, 0.01),
          );
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final fromDashboard in [true, false]) {
    testWidgets(
      'Application flow from ${fromDashboard ? 'Dashboard' : 'Loans'} requires a co-maker',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(const MaterialApp(home: Dashboard()));
        await tester.pumpAndSettle();
        if (fromDashboard) {
          await tapText(tester, 'Apply for a Loan');
        } else {
          await tester.tap(
            find.descendant(
              of: find.byType(AppBottomNavigationBar),
              matching: find.byIcon(Icons.payments),
            ),
          );
          await tester.pumpAndSettle();
        }
        final apply = find.text('Apply Now').first;
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(fromDashboard ? 320 : 360, 850);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();

        expect(find.byType(ProfileConfirmationScreen), findsOneWidget);
        expect(find.text('Test Borrower'), findsOneWidget);
        expect(find.textContaining('Verify a co-maker'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tapText(tester, 'Proceed to Loan Calculator');
        await tester.pumpAndSettle();

        final flow = tester
            .widget<LoanCalculatorScreen>(find.byType(LoanCalculatorScreen))
            .flow;
        expect(flow.previewOnly, isFalse);
        expect(flow.requireCoMaker, isTrue);
        expect(flow.canUseLiveSubmission, isTrue);
        expect(flow.draft.applicant?['member_id'], 'MEM-001');
        expect(find.text('Continue to Participants'), findsOneWidget);
        expect(requests.every((request) => request.method == 'GET'), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(flow.isActive, isFalse);
      },
    );
  }

  testWidgets('Preview flow cannot send OTP through the legacy screen', (
    tester,
  ) async {
    final flow = LoanApplicationFlow(
      LoanType.regular,
      client,
      previewOnly: true,
    );
    addTearDown(() => flow.close(removeRoutes: false));
    await tester.pumpWidget(
      MaterialApp(home: EmailOtpVerificationScreen(flow: flow)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Submission Not Yet Available'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('Dashboard Apply for a Loan opens the selected product', (
    tester,
  ) async {
    await start(tester, dashboard: true);
    final screen = tester.widget<LoanCalculatorScreen>(
      find.byType(LoanCalculatorScreen),
    );
    expect(screen.flow.draft.loanType, LoanType.emergency);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Available Loans retains profile and draft state entering participants',
    (tester) async {
      await start(tester, dashboard: false);
      final calculator = find.byType(LoanCalculatorScreen);
      final flow = tester.widget<LoanCalculatorScreen>(calculator).flow;
      expect(flow.draft.loanType, LoanType.emergency);
      expect(flow.draft.applicant?['member_id'], 'MEM-001');
      expect(
        tester
            .widget<LoanProgressIndicator>(find.byType(LoanProgressIndicator))
            .currentStep,
        0,
      );
      final amount = find.byType(TextField);
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '60000');
      await tester.pump();
      await tester.enterText(amount, 'NaN');
      expect(flow.draft.amount, 60000);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(tester.widget<TextField>(amount).controller?.text, '60000');
      await tapText(tester, 'New');
      expect(flow.draft.applicationKind?.label, 'New');
      await tapText(tester, 'Renewal');
      expect(flow.draft.applicationKind?.label, 'Renewal');
      await tapText(tester, '6mo');
      expect(flow.draft.computation?.totalInterest, 5400);
      expect(flow.draft.tenure, 6);
      Navigator.of(tester.element(calculator)).pop();
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
      await tapText(tester, 'Proceed to Loan Calculator');
      expect(tester.widget<TextField>(amount).controller?.text, '60000');
      expect(flow.draft.tenure, 6);

      for (final kind in [LoanDocumentKind.payslip, LoanDocumentKind.validId]) {
        flow.draft.documents[kind] = SelectedLoanDocument.fromBytes(
          kind: kind,
          name: '${kind.name}.pdf',
          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        );
      }
      flow.draft.participants = LoanParticipantsDraft()
        ..coMaker = const LoanCoMakerCandidate(
          memberId: 'CSUCC-2099-9002',
          name: 'Verified Test Co-maker',
          isVerifiedMember: true,
        )
        ..relationship = 'Colleague'
        ..witnessOne = 'Test Witness One'
        ..witnessTwo = 'Test Witness Two'
        ..coMakerIdDocument = SelectedLoanDocument.fromBytes(
          kind: LoanDocumentKind.validId,
          name: 'co-maker-id.pdf',
          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        );
      await tapText(tester, 'Continue to Participants');
      expect(find.byType(LoanParticipantsScreen), findsOneWidget);
      expect(
        flow.draft.documents.keys,
        containsAll([LoanDocumentKind.payslip, LoanDocumentKind.validId]),
      );
      expect(flow.draft.tenure, 6);
      expect(flow.draft.applicationKind?.label, 'Renewal');
      expect(requests.where((request) => request.method == 'POST'), isEmpty);

      final oldDraft = flow.draft;
      await client.auth.signInWithPassword(
        email: 'other@example.test',
        password: 'test-password',
      );
      await tester.pumpAndSettle();
      expect(flow.isActive, false);
      expect(oldDraft.applicant, isNull);
      expect(oldDraft.documents, isEmpty);
      expect(find.byType(LoansScreen), findsOneWidget);
      expect(find.byType(ProfileConfirmationScreen), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

Future<void> tapText(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _FailingLookup implements LoanParticipantLookup {
  @override
  Future<LoanCoMakerCandidate?> findByName(String name) async =>
      throw StateError('Unavailable');
}

Future<void> enterParticipantField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> selectRelationship(
  WidgetTester tester,
  String relationship,
) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(relationship).last);
  await tester.pumpAndSettle();
}

ElevatedButton demoButton(WidgetTester tester, String label) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));

Future<void> acknowledge(WidgetTester tester) async {
  final checkbox = find.byType(CheckboxListTile);
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await tester.pumpAndSettle();
}

Future<void> enterDemoCode(
  WidgetTester tester,
  String value, {
  bool repeatTap = false,
}) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.pumpAndSettle();
  final button = find.text('Verify Demo Code');
  await tester.ensureVisible(button);
  await tester.tap(button);
  if (repeatTap) await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}
