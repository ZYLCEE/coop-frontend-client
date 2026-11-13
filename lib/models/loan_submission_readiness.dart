import '../loan_calculator_service.dart';
import 'loan_agreement_snapshot.dart';
import 'loan_document.dart';

enum DemoCoMakerDecision { pending, confirmed, declined }

enum LoanReadinessStatus {
  complete('Complete'),
  incomplete('Incomplete'),
  selectedLocally('Selected Locally'),
  demoConfirmed('Demo Confirmed'),
  demoConsentRecorded('Demo Consent Recorded'),
  declined('Declined'),
  pendingBackend('Pending Backend Verification'),
  pendingCooperative('Pending Cooperative Confirmation'),
  unavailableInDemo('Not Available in Demo'),
  unavailableInPreview('Submission Not Yet Available');

  const LoanReadinessStatus(this.label);
  final String label;
}

typedef LoanReadinessItem = ({
  String label,
  LoanReadinessStatus status,
  String? detail,
});

/// Reports what the demo actually captured. It grants no submission authority.
class LoanSubmissionReadiness {
  const LoanSubmissionReadiness._(this.items, this.previewCompleted);

  final List<LoanReadinessItem> items;
  final bool previewCompleted;

  factory LoanSubmissionReadiness.forDemo({
    required LoanAgreementSnapshot snapshot,
    required bool activeSession,
    required bool borrowerDemoConfirmed,
    required DemoCoMakerDecision coMakerDecision,
  }) => LoanSubmissionReadiness._evaluate(
    snapshot: snapshot,
    activeSession: activeSession,
    borrowerDemoConfirmed: borrowerDemoConfirmed,
    coMakerDecision: coMakerDecision,
  );

  factory LoanSubmissionReadiness.forLocalPreview({
    required LoanAgreementSnapshot snapshot,
    required bool activeSession,
  }) => LoanSubmissionReadiness._evaluate(
    snapshot: snapshot,
    activeSession: activeSession,
    localPreview: true,
  );

  factory LoanSubmissionReadiness._evaluate({
    required LoanAgreementSnapshot snapshot,
    required bool activeSession,
    bool borrowerDemoConfirmed = false,
    DemoCoMakerDecision coMakerDecision = DemoCoMakerDecision.pending,
    bool localPreview = false,
  }) {
    final hasApplicant =
        snapshot.profileConfirmed &&
        _hasText(snapshot.applicant['member_id']) &&
        _hasText(snapshot.applicant['first_name']) &&
        _hasText(snapshot.applicant['last_name']);
    final policy = snapshot.policy;
    final calculation = snapshot.computation;
    final validLoan =
        snapshot.amount.isFinite &&
        snapshot.amount > 0 &&
        snapshot.amount >= policy.minLoanAmount &&
        snapshot.amount <= policy.maxLoanAmount &&
        LoanTypeCatalog.available.contains(snapshot.loanType) &&
        const {3, 6, 12, 24}.contains(snapshot.tenure) &&
        calculation.principal == snapshot.amount &&
        calculation.paymentDates.length == snapshot.tenure &&
        calculation.interestRate == policy.baseInterestRatePercent &&
        [
          calculation.totalInterest,
          calculation.processingFee,
          calculation.notarialFee,
          calculation.retentionFee,
          calculation.netTakeHome,
          calculation.monthlyAmortization,
        ].every((amount) => amount.isFinite);

    final missing = snapshot.visibleDocumentKinds
        .where(
          (kind) =>
              snapshot.requiresDocument(kind) &&
              !snapshot.documents.containsKey(kind),
        )
        .map((kind) => kind.label)
        .toList();
    final invalid = snapshot.documents.entries
        .where((entry) {
          final file = entry.value;
          return file.name.trim().isEmpty ||
              !SelectedLoanDocument.supportedExtensions.contains(
                file.extension,
              ) ||
              file.sizeBytes < 1 ||
              file.sizeBytes > SelectedLoanDocument.maxBytes;
        })
        .map((entry) => entry.key.label)
        .toList();
    final documentsComplete = missing.isEmpty && invalid.isEmpty;
    final hasCoMaker =
        snapshot.coMaker != null &&
        snapshot.coMaker!.memberId.trim().isNotEmpty &&
        snapshot.relationship.isNotEmpty;
    final borrowerConfirmed = activeSession && borrowerDemoConfirmed;
    final coMakerConfirmed =
        borrowerConfirmed &&
        hasCoMaker &&
        coMakerDecision == DemoCoMakerDecision.confirmed;
    final conflict =
        snapshot.participantsDemo ||
        snapshot.collateralRequiredAbove != legacyCollateralRequiredAbove;
    final ratesDiffer =
        policy.baseInterestRatePercent != 2 || policy.serviceFeePercent != 1;

    return LoanSubmissionReadiness._(
      List.unmodifiable([
        _item(
          'Signed-in member session',
          _completion(activeSession),
          'Local session check. Server identity and authorization still need validation.',
        ),
        _item('Applicant information', _completion(hasApplicant)),
        _item('Loan details', _completion(validLoan)),
        _item(
          'Documents',
          documentsComplete
              ? LoanReadinessStatus.selectedLocally
              : LoanReadinessStatus.incomplete,
          [
            if (missing.isNotEmpty) 'Missing: ${missing.join(', ')}.',
            if (invalid.isNotEmpty) 'Invalid metadata: ${invalid.join(', ')}.',
            if (documentsComplete) 'Selected files remain in this draft.',
          ].join(' '),
        ),
        if (conflict)
          _item(
            'Collateral policy',
            LoanReadinessStatus.pendingCooperative,
            '${localPreview ? '' : 'Proposed demo rule: ₱200,000 and above. '}'
                'The configured Documents rule requires collateral over '
                '${LoanCalculatorService.formatCurrency(snapshot.collateralRequiredAbove)}, and the legacy '
                'upload precheck requires it over ₱200,000. CSUCC confirmation is pending.',
          ),
        _item(
          'Borrower consent',
          localPreview
              ? LoanReadinessStatus.pendingBackend
              : borrowerConfirmed
              ? LoanReadinessStatus.demoConfirmed
              : LoanReadinessStatus.incomplete,
        ),
        _item(
          'Co-maker selection',
          localPreview
              ? LoanReadinessStatus.pendingBackend
              : _completion(hasCoMaker),
        ),
        _item('Co-maker eligibility', LoanReadinessStatus.pendingBackend),
        _item(
          'Co-Maker',
          localPreview
              ? LoanReadinessStatus.pendingBackend
              : coMakerConfirmed
              ? LoanReadinessStatus.demoConsentRecorded
              : activeSession &&
                    coMakerDecision == DemoCoMakerDecision.declined &&
                    hasCoMaker
              ? LoanReadinessStatus.declined
              : LoanReadinessStatus.incomplete,
        ),
        _item(
          'Authenticated consent and agreement version',
          LoanReadinessStatus.pendingBackend,
        ),
        _witness('Witness 1', snapshot.witnessOne),
        _witness('Witness 2', snapshot.witnessTwo),
        _item('Employer Certification', LoanReadinessStatus.pendingCooperative),
        _item(
          'Promissory Note',
          LoanReadinessStatus.pendingCooperative,
          'Approved digital template pending.',
        ),
        _item(
          'Terms and financial policy',
          LoanReadinessStatus.pendingCooperative,
          ratesDiffer
              ? 'The configured rate or service fee differs from the existing Terms, which state 2% monthly interest and a 1% service fee.'
              : 'The existing Terms state 2% monthly interest and a 1% service fee. Approval of the digital wording is pending.',
        ),
        _item(
          'Notarial acknowledgment',
          LoanReadinessStatus.pendingCooperative,
        ),
        _item(
          'Application submission',
          localPreview
              ? LoanReadinessStatus.unavailableInPreview
              : LoanReadinessStatus.unavailableInDemo,
        ),
      ]),
      activeSession &&
          hasApplicant &&
          validLoan &&
          documentsComplete &&
          borrowerConfirmed &&
          coMakerConfirmed,
    );
  }

  static bool _hasText(Object? value) =>
      value is String && value.trim().isNotEmpty;

  static LoanReadinessStatus _completion(bool complete) =>
      complete ? LoanReadinessStatus.complete : LoanReadinessStatus.incomplete;

  static LoanReadinessItem _item(
    String label,
    LoanReadinessStatus status, [
    String? detail,
  ]) => (label: label, status: status, detail: detail);

  static LoanReadinessItem _witness(String label, String name) => _item(
    label,
    LoanReadinessStatus.pendingCooperative,
    name.isEmpty
        ? 'No name entered. Attestation procedure pending.'
        : '$name · Attestation Pending',
  );
}
