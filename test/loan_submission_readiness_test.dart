import 'dart:convert';
import 'dart:typed_data';

import 'package:coop_frontend/loan_calculator_service.dart';
import 'package:coop_frontend/models/loan_agreement_snapshot.dart';
import 'package:coop_frontend/models/loan_application_draft.dart';
import 'package:coop_frontend/models/loan_document.dart';
import 'package:coop_frontend/models/loan_participant.dart';
import 'package:coop_frontend/models/loan_policy.dart';
import 'package:coop_frontend/models/loan_submission_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LoanApplicationDraft sampleDraft({double amount = 50000}) {
    final draft = LoanApplicationDraft(loanType: LoanType.regular)
      ..applicant = {
        'member_id': 'DEMO-MEMBER',
        'first_name': 'Sample',
        'last_name': 'Borrower',
      }
      ..profileConfirmed = true
      ..amount = amount
      ..policy = LoanPolicySettings.fromMap({
        'base_interest_rate': 1.5,
        'processing_fee_percent': 1,
        'service_fee_percent': 0.5,
        'min_member_tenure_months': 6,
        'min_loan_amount': 1000,
        'max_loan_amount': 500000,
        'max_loan_multiplier': 3,
        'penalty_rate_percent': 2,
        'co_maker_required_above': 50000,
        'collateral_required_above': 150000,
        'loan_processing_time': '3–5',
      })
      ..computation = LoanCalculatorService().calculate(
        principal: amount,
        months: 12,
        loanType: LoanType.regular,
      )
      ..participants = (LoanParticipantsDraft()
        ..coMaker = const LoanCoMakerCandidate(
          memberId: 'DEMO-COMAKER',
          name: 'Sample Co-Maker',
        )
        ..relationship = 'Colleague'
        ..witnessOne = 'Sample Witness');
    for (final kind in [LoanDocumentKind.payslip, LoanDocumentKind.validId]) {
      draft.documents[kind] = SelectedLoanDocument.fromBytes(
        kind: kind,
        name: '${kind.name}.pdf',
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
      );
    }
    return draft;
  }

  LoanReadinessItem item(LoanSubmissionReadiness readiness, String label) =>
      readiness.items.singleWhere((entry) => entry.label == label);

  test(
    'A completed demo reports pending formalities and blocks submission',
    () {
      final readiness = LoanSubmissionReadiness.forDemo(
        snapshot: LoanAgreementSnapshot.fromDraft(
          sampleDraft(),
          participantsDemo: true,
        ),
        activeSession: true,
        borrowerDemoConfirmed: true,
        coMakerDecision: DemoCoMakerDecision.confirmed,
      );
      expect(readiness.previewCompleted, true);
      expect(
        item(readiness, 'Documents').status,
        LoanReadinessStatus.selectedLocally,
      );
      expect(
        item(readiness, 'Borrower consent').status,
        LoanReadinessStatus.demoConfirmed,
      );
      expect(
        item(readiness, 'Co-Maker').status,
        LoanReadinessStatus.demoConsentRecorded,
      );
      expect(
        item(readiness, 'Co-maker eligibility').status,
        LoanReadinessStatus.pendingBackend,
      );
      expect(
        item(readiness, 'Authenticated consent and agreement version').status,
        LoanReadinessStatus.pendingBackend,
      );
      for (final label in [
        'Witness 1',
        'Witness 2',
        'Employer Certification',
        'Promissory Note',
        'Notarial acknowledgment',
        'Terms and financial policy',
        'Collateral policy',
      ]) {
        expect(
          item(readiness, label).status,
          LoanReadinessStatus.pendingCooperative,
        );
      }
      expect(
        item(readiness, 'Terms and financial policy').detail,
        contains('differs'),
      );
      expect(
        item(readiness, 'Application submission').status,
        LoanReadinessStatus.unavailableInDemo,
      );
    },
  );

  for (final (amount, required) in [
    (199999.99, false),
    (200000.0, true),
    (200000.01, true),
  ]) {
    test('Demo collateral boundary at $amount excludes inactive files', () {
      final draft = sampleDraft(amount: amount);
      const kind = LoanDocumentKind.collateral;
      final file = SelectedLoanDocument.fromBytes(
        kind: kind,
        name: 'collateral.pdf',
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
      );
      LoanAgreementSnapshot snapshot() =>
          LoanAgreementSnapshot.fromDraft(draft, participantsDemo: true);
      LoanSubmissionReadiness readiness() => LoanSubmissionReadiness.forDemo(
        snapshot: snapshot(),
        activeSession: true,
        borrowerDemoConfirmed: true,
        coMakerDecision: DemoCoMakerDecision.confirmed,
      );
      expect(snapshot().requiresDocument(kind), required);
      expect(snapshot().visibleDocumentKinds.contains(kind), required);
      expect(
        item(readiness(), 'Documents').status,
        required
            ? LoanReadinessStatus.incomplete
            : LoanReadinessStatus.selectedLocally,
      );
      expect(
        item(readiness(), 'Collateral policy').detail,
        contains('₱150000.00'),
      );
      expect(
        item(readiness(), 'Collateral policy').detail,
        contains('over ₱200,000'),
      );
      draft.documents[kind] = file;
      expect(snapshot().documents.containsKey(kind), required);
      expect(
        item(readiness(), 'Documents').status,
        LoanReadinessStatus.selectedLocally,
      );
      final live = LoanAgreementSnapshot.fromDraft(draft);
      expect(live.visibleDocumentKinds, contains(kind));
      expect(live.requiresDocument(kind), isTrue);
      expect(live.documents, contains(kind));
    });
  }

  test(
    'Incomplete applicant, stale calculation and missing collateral are visible',
    () {
      final draft = sampleDraft(amount: 200000)
        ..profileConfirmed = false
        ..tenure = 6;
      final readiness = LoanSubmissionReadiness.forDemo(
        snapshot: LoanAgreementSnapshot.fromDraft(
          draft,
          participantsDemo: true,
        ),
        activeSession: false,
        borrowerDemoConfirmed: true,
        coMakerDecision: DemoCoMakerDecision.confirmed,
      );
      expect(readiness.previewCompleted, false);
      for (final label in [
        'Signed-in member session',
        'Applicant information',
        'Loan details',
        'Documents',
        'Borrower consent',
        'Co-Maker',
      ]) {
        expect(item(readiness, label).status, LoanReadinessStatus.incomplete);
      }
      expect(
        item(readiness, 'Documents').detail,
        contains('Collateral Document'),
      );
    },
  );
}
