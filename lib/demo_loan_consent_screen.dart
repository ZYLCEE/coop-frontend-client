import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'bellicon.dart';
import 'loan_calculator_service.dart';
import 'loan_application_flow.dart';
import 'models/loan_agreement_snapshot.dart';
import 'models/loan_submission_readiness.dart';
import 'responsive.dart';
import 'services/demo_loan_consent_service.dart';
import 'widgets/loan_agreement_preview.dart';
import 'widgets/loan_progress_indicator.dart';

/// Consent belongs to this review route and its captured snapshot. Reopening
/// review after returning to an editable step always starts a new revision.
class DemoLoanConsentScreen extends StatefulWidget {
  const DemoLoanConsentScreen({
    super.key,
    required this.flow,
    required this.snapshot,
  });

  final LoanApplicationFlow flow;
  final LoanAgreementSnapshot snapshot;

  @override
  State<DemoLoanConsentScreen> createState() => _DemoLoanConsentScreenState();
}

class _DemoLoanConsentScreenState extends State<DemoLoanConsentScreen> {
  late final int? _revision;
  bool _acknowledged = false;
  bool _borrowerConfirmed = false;
  bool _showReadiness = false;
  @override
  void initState() {
    super.initState();
    _revision = widget.flow.beginConsentDemoReview(widget.snapshot);
  }

  @override
  void dispose() {
    if (_revision case final revision?) {
      widget.flow.endConsentDemoReview(revision);
    }
    super.dispose();
  }

  void _verifyBorrower(int revision) {
    if (widget.flow.hasDemoCoMakerDeclined(widget.snapshot.coMaker?.memberId)) {
      return;
    }
    if (!_acknowledged ||
        _borrowerConfirmed ||
        !widget.flow.canUseConsentDemo) {
      return;
    }
    widget.flow.push(
      context,
      (_) => _DemoOtpScreen(
        flow: widget.flow,
        revision: revision,
        role: 'Borrower',
        isCurrent: () => widget.flow.isCurrentDemoReview(revision),
        onConfirmed: () {
          if (mounted && widget.flow.canUseConsentDemo) {
            widget.flow.recordDemoBorrowerConfirmation(
              revision,
              widget.snapshot,
            );
            setState(() => _borrowerConfirmed = true);
          }
        },
      ),
    );
  }

  Future<void> _openInbox(DemoCoMakerRequest request) async {
    if (!widget.flow.canRespondToDemoRequest(request)) return;
    await widget.flow.push(
      context,
      (_) => _DemoCoMakerInbox(
        flow: widget.flow,
        request: request,
        snapshot: widget.snapshot,
      ),
    );
    if (mounted && widget.flow.isCurrentDemoReview(request.revision)) {
      setState(() {
        _showReadiness = request.decision == DemoCoMakerDecision.confirmed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.flow.canUseConsentDemo || _revision == null) {
      return const SizedBox.shrink();
    }
    final revision = _revision;
    final coMaker = widget.snapshot.coMaker;
    final request = coMaker == null
        ? null
        : widget.flow.demoRequestFor(revision, coMaker.memberId);
    if (!widget.flow.isCurrentDemoReview(revision)) {
      return _AgreementPage(
        title: 'Borrower Application',
        revision: revision,
        children: const [
          Text(
            'This agreement changed. Reopen the application preview to start a new review.',
          ),
        ],
      );
    }
    final coMakerDecision =
        request?.decision ??
        (widget.flow.hasDemoCoMakerDeclined(coMaker?.memberId)
            ? DemoCoMakerDecision.declined
            : DemoCoMakerDecision.pending);
    if (_showReadiness) {
      return _ApplicationReadinessPage(
        revision: revision,
        readiness: LoanSubmissionReadiness.forDemo(
          snapshot: widget.snapshot,
          activeSession: widget.flow.canUseConsentDemo,
          borrowerDemoConfirmed: _borrowerConfirmed,
          coMakerDecision: coMakerDecision,
        ),
        onReturn: () => setState(() => _showReadiness = false),
      );
    }
    return _AgreementPage(
      title: 'Agreement and Terms Preview',
      revision: revision,
      children: [
        const Text(
          'Borrower Application · Prototype confirmation. Submission is disabled for this practice draft.',
          style: AppTheme.bodyRegular,
        ),
        const SizedBox(height: AppTheme.spacingL),
        LoanAgreementPreview(snapshot: widget.snapshot),
        const SizedBox(height: AppTheme.spacingL),
        TextButton(
          onPressed: () => setState(() => _showReadiness = true),
          child: const Text('View Application Readiness'),
        ),
        const SizedBox(height: AppTheme.spacingM),
        if (!_borrowerConfirmed &&
            coMakerDecision != DemoCoMakerDecision.declined) ...[
          _Acknowledgment(
            label:
                'I reviewed this preview and understand this is a prototype confirmation.',
            value: _acknowledged,
            onChanged: (value) => setState(() => _acknowledged = value),
          ),
          _DemoButton(
            label: 'Continue to Verification',
            onPressed: _acknowledged ? () => _verifyBorrower(revision) : null,
          ),
        ] else ...[
          if (request != null &&
              request.decision == DemoCoMakerDecision.pending) ...[
            LoanReviewSection(
              title: 'Developer Demonstration',
              children: [
                const Text(
                  'Preview the selected fictional co-maker’s inbox. This does '
                  'not switch accounts or deliver a real notification.',
                  style: AppTheme.bodyRegular,
                ),
                const SizedBox(height: AppTheme.spacingM),
                _DemoButton(
                  label: 'Open Fictional Co-Maker Inbox',
                  onPressed: () => _openInbox(request),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
          LoanReviewSection(
            title: 'Participant Status',
            children: [
              Text(
                _borrowerConfirmed
                    ? 'Borrower: Demo Confirmed'
                    : 'Borrower: Demo Confirmation Pending',
              ),
              Text(
                'Co-Maker: ${switch (coMakerDecision) {
                  DemoCoMakerDecision.pending => request != null ? 'Awaiting Response' : (coMaker == null ? 'No selection' : 'Pending'),
                  DemoCoMakerDecision.confirmed => 'Demo Consent Recorded',
                  DemoCoMakerDecision.declined => 'Declined',
                }}',
              ),
              if (coMakerDecision == DemoCoMakerDecision.declined)
                const Text(
                  'Return to Participants to select a replacement. The loan details and documents stay in your draft.',
                ),
              const SizedBox(height: AppTheme.spacingM),
              const Text('Witness 1: Attestation Pending'),
              const Text('Witness 2: Attestation Pending'),
              const Text('Notarial acknowledgment: Pending'),
              const SizedBox(height: AppTheme.spacingM),
              const Text(
                'Demo Incomplete – Not Submitted',
                style: AppTheme.bodyBold,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DemoCoMakerInbox extends StatefulWidget {
  const _DemoCoMakerInbox({
    required this.flow,
    required this.request,
    required this.snapshot,
  });

  final LoanApplicationFlow flow;
  final DemoCoMakerRequest request;
  final LoanAgreementSnapshot snapshot;

  @override
  State<_DemoCoMakerInbox> createState() => _DemoCoMakerInboxState();
}

class _DemoCoMakerInboxState extends State<_DemoCoMakerInbox> {
  Future<void> _reviewRequest() async {
    final request = widget.request;
    if (!widget.flow.canRespondToDemoRequest(request) ||
        !widget.flow.markDemoRequestRead(request)) {
      return;
    }
    await widget.flow.push(
      context,
      (_) => ParticipantAgreementReviewScreen._(
        flow: widget.flow,
        snapshot: widget.snapshot,
        request: request,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.request;
    final request = widget.flow.demoRequestFor(
      entry.revision,
      entry.recipient.memberId,
    );
    return _AgreementPage(
      title: 'Fictional Co-Maker Inbox',
      revision: entry.revision,
      children: [
        const Text(
          'Developer demonstration only. This inbox is separate from member notifications.',
          style: AppTheme.bodyRegular,
        ),
        const SizedBox(height: AppTheme.spacingM),
        if (request != entry)
          const Text('No active demo requests.')
        else ...[
          Text(
            'Fictional recipient: ${entry.recipient.name}',
            style: AppTheme.bodyBold,
          ),
          const SizedBox(height: AppTheme.spacingM),
          NotificationCard(
            notification: NotificationItem(
              id: entry.revision,
              title: 'Co-Maker Request',
              timestamp: entry.isRead ? 'Read' : 'New',
              description:
                  'Demo request · ${entry.product}\n'
                  'Requested amount: ${LoanCalculatorService.formatCurrency(entry.amount)}\n'
                  '${_demoRequestStatus(entry.decision)}',
              actionText: entry.decision == DemoCoMakerDecision.pending
                  ? 'Review Request'
                  : null,
              icon: Icons.person_add_outlined,
              iconColor: AppTheme.primaryGreen,
              iconBgColor: AppTheme.background,
              isHighlighted: !entry.isRead,
            ),
            onAction: _reviewRequest,
          ),
        ],
      ],
    );
  }
}

/// Review-only borrower entry. The fictional inbox and OTP routes are separate.
class BorrowerAgreementPreviewScreen extends StatelessWidget {
  const BorrowerAgreementPreviewScreen({
    super.key,
    required this.flow,
    required this.snapshot,
  });

  final LoanApplicationFlow flow;
  final LoanAgreementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!flow.isActive || !flow.previewOnly) {
      return const SizedBox.shrink();
    }
    return _AgreementPage(
      title: 'Agreement Preview',
      children: [
        const Text(
          'Review the available information and draft estimates for the updated application. '
          'Online submission, agreement verification and consent are not yet available.',
          style: AppTheme.bodyRegular,
        ),
        const SizedBox(height: AppTheme.spacingL),
        LoanAgreementPreview(snapshot: snapshot, localPreview: true),
        const SizedBox(height: AppTheme.spacingL),
        _DemoButton(
          label: 'View Application Readiness',
          onPressed: () => flow.push(
            context,
            (readinessContext) => _ApplicationReadinessPage(
              readiness: LoanSubmissionReadiness.forLocalPreview(
                snapshot: snapshot,
                activeSession: flow.isActive,
              ),
              onReturn: () => Navigator.of(readinessContext).pop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationReadinessPage extends StatelessWidget {
  const _ApplicationReadinessPage({
    this.revision,
    required this.readiness,
    required this.onReturn,
  });

  final int? revision;
  final LoanSubmissionReadiness readiness;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => _AgreementPage(
    title: 'Application Readiness',
    revision: revision,
    children: [
      LoanReviewSection(
        title: revision == null
            ? 'Submission Not Yet Available'
            : readiness.previewCompleted
            ? 'Application Preview Completed'
            : 'Application Preview In Progress',
        children: [
          if (revision == null)
            const Text(
              'Your draft stays on this device for this session. '
              'Authorized participant checks, consent and server validation are required before submission.',
              style: AppTheme.bodyRegular,
            )
          else ...const [
            Text(
              'This demonstration shows the proposed loan application and consent workflow. No real loan application has been submitted to the cooperative.',
              style: AppTheme.bodyRegular,
            ),
            SizedBox(height: AppTheme.spacingM),
            Text('Demo Incomplete – Not Submitted', style: AppTheme.bodyBold),
          ],
        ],
      ),
      const SizedBox(height: AppTheme.spacingL),
      LoanReviewSection(
        title: 'Readiness Checklist',
        children: [
          for (final item in readiness.items) ...[
            Text(
              '${item.label}: ${item.status.label}',
              style: AppTheme.bodyBold,
            ),
            if (item.detail case final detail?)
              Text(detail, style: AppTheme.captionRegular),
            if (item != readiness.items.last) const Divider(),
          ],
        ],
      ),
      const SizedBox(height: AppTheme.spacingL),
      _DemoButton(label: 'Return to Agreement Preview', onPressed: onReturn),
    ],
  );
}

String _demoRequestStatus(DemoCoMakerDecision decision) => switch (decision) {
  DemoCoMakerDecision.pending => 'Awaiting Co-Maker Response',
  DemoCoMakerDecision.confirmed => 'Co-Maker Demo Consent Recorded',
  DemoCoMakerDecision.declined => 'Co-Maker Declined',
};

/// Read-only agreement for the assigned fictional recipient.
class ParticipantAgreementReviewScreen extends StatefulWidget {
  const ParticipantAgreementReviewScreen._({
    required this.flow,
    required this.snapshot,
    required this.request,
  });

  final LoanApplicationFlow flow;
  final LoanAgreementSnapshot snapshot;
  final DemoCoMakerRequest request;

  @override
  State<ParticipantAgreementReviewScreen> createState() =>
      _ParticipantAgreementReviewScreenState();
}

class _ParticipantAgreementReviewScreenState
    extends State<ParticipantAgreementReviewScreen> {
  bool _acknowledged = false;

  bool get _canRespond => widget.flow.canRespondToDemoRequest(widget.request);

  void _finish(DemoCoMakerDecision decision) {
    if (mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        widget.flow.resolveDemoRequest(widget.request, decision)) {
      setState(() {});
    }
  }

  Future<void> _decline() async {
    if (!_canRespond) return;
    var confirmed = false;
    await widget.flow.push(
      context,
      (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Decline this demo request?'),
        content: const Text(
          'Declining means the fictional co-maker will not participate in this proposed loan application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Confirm Decline'),
          ),
        ],
      ),
      dialog: true,
    );
    if (confirmed) _finish(DemoCoMakerDecision.declined);
  }

  Future<void> _verify() async {
    if (!_acknowledged || !_canRespond) return;
    var confirmed = false;
    await widget.flow.push(
      context,
      (_) => _DemoOtpScreen(
        flow: widget.flow,
        revision: widget.request.revision,
        role: 'Co-Maker',
        fictionalRecipient: widget.request.recipient.name,
        isCurrent: () => _canRespond,
        onConfirmed: () => confirmed = true,
      ),
    );
    if (confirmed) _finish(DemoCoMakerDecision.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    if (!widget.flow.canUseConsentDemo) return const SizedBox.shrink();
    final isCurrent =
        widget.flow.demoRequestFor(
          request.revision,
          request.recipient.memberId,
        ) ==
        request;
    return _AgreementPage(
      title: 'Co-Maker Loan Agreement Review',
      revision: request.revision,
      children: [
        if (!isCurrent)
          const Text('This demo request is no longer active.')
        else if (request.decision != DemoCoMakerDecision.pending)
          LoanReviewSection(
            title: _demoRequestStatus(request.decision),
            children: const [
              Text('This decision applies to the fictional request only.'),
            ],
          )
        else ...[
          LoanReviewSection(
            title: 'Fictional Co-Maker · ${request.recipient.name}',
            children: const [
              Text(
                'You are reviewing this request as the proposed co-maker in a fictional demonstration.',
                style: AppTheme.bodyRegular,
              ),
              SizedBox(height: AppTheme.spacingS),
              Text(
                'The paper form describes joint and several liability. A co-maker may take on substantial repayment obligations.',
                style: AppTheme.bodyRegular,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          LoanAgreementPreview(
            snapshot: widget.snapshot,
            showApplicantDetails: false,
            fictionalBorrowerName: 'Demo Borrower',
          ),
          const SizedBox(height: AppTheme.spacingL),
          _Acknowledgment(
            label:
                'I reviewed the available terms and acknowledge the proposed co-maker obligations for this demo.',
            value: _acknowledged,
            onChanged: (value) => setState(() => _acknowledged = value),
          ),
          _DemoButton(
            label: 'Continue to Consent',
            onPressed: _acknowledged ? _verify : null,
          ),
          TextButton(onPressed: _decline, child: const Text('Decline Request')),
        ],
        if (!isCurrent || request.decision != DemoCoMakerDecision.pending) ...[
          const SizedBox(height: AppTheme.spacingM),
          _DemoButton(
            label: 'Back to Fictional Inbox',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}

class _DemoOtpScreen extends StatefulWidget {
  const _DemoOtpScreen({
    required this.flow,
    required this.revision,
    required this.role,
    required this.onConfirmed,
    required this.isCurrent,
    this.fictionalRecipient,
  });

  final LoanApplicationFlow flow;
  final int revision;
  final String role;
  final VoidCallback onConfirmed;
  final bool Function() isCurrent;
  final String? fictionalRecipient;

  @override
  State<_DemoOtpScreen> createState() => _DemoOtpScreenState();
}

class _DemoOtpScreenState extends State<_DemoOtpScreen> {
  final _code = TextEditingController();
  late final _simulation = DemoLoanConsentService(
    enabled: () =>
        mounted && widget.flow.canUseConsentDemo && widget.isCurrent(),
  );
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _simulation.issue();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_checking || !widget.flow.canUseConsentDemo) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted ||
        !widget.flow.canUseConsentDemo ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final result = _simulation.verify(_code.text);
    if (result == DemoOtpResult.confirmed) {
      _code.clear();
      widget.onConfirmed();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _checking = false;
      _error = switch (result) {
        DemoOtpResult.invalid => 'Incorrect demo code. Try again.',
        DemoOtpResult.expired =>
          'Demo challenge expired. Restart it to try again.',
        _ => 'Demo challenge unavailable. Restart it to try again.',
      };
    });
  }

  void _restart() {
    if (!_simulation.issue()) return;
    setState(() {
      _error = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.flow.canUseConsentDemo) return const SizedBox.shrink();
    if (!widget.isCurrent()) {
      return _AgreementPage(
        title: 'Demo Verification Unavailable',
        revision: widget.revision,
        children: const [
          Text(
            'This agreement or request is no longer active. Go back to review the current state.',
          ),
        ],
      );
    }
    return _AgreementPage(
      title: '${widget.role} Demo Verification',
      revision: widget.revision,
      children: [
        LoanReviewSection(
          title: 'Enter the Demo Code',
          children: [
            if (widget.fictionalRecipient case final recipient?)
              Text('Fictional co-maker: $recipient', style: AppTheme.bodyBold),
            const Text(
              'Practice code: ${DemoLoanConsentService.sampleCode}. This local challenge expires in one minute.',
              style: AppTheme.bodyRegular,
            ),
            const SizedBox(height: AppTheme.spacingL),
            TextField(
              controller: _code,
              enabled: !_checking,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: '8-digit demo code',
                errorText: _error,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _DemoButton(
              label: _checking ? 'Checking Demo Code…' : 'Verify Demo Code',
              onPressed: !_checking && _code.text.length == 8 ? _verify : null,
            ),
            TextButton(
              onPressed: _checking ? null : _restart,
              child: const Text('Restart Demo Challenge'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgreementPage extends StatelessWidget {
  const _AgreementPage({
    required this.title,
    this.revision,
    required this.children,
  });

  final String title;
  final int? revision;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      backgroundColor: AppTheme.cardWhite,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppTheme.mutedGray,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        title,
        style: AppTheme.titleBold,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoanProgressIndicator.forApplication(
              LoanApplicationStep.review,
              participantsDemo: revision != null,
              previewOnly: revision == null,
            ),
            const SizedBox(height: AppTheme.spacingL),
            if (revision case final number?) ...[
              Text('Local demo revision $number', style: AppTheme.captionBold),
              const SizedBox(height: AppTheme.spacingM),
            ],
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _Acknowledgment extends StatelessWidget {
  const _Acknowledgment({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    activeColor: AppTheme.primaryGreen,
    title: Text(label, style: AppTheme.bodyRegular),
    value: value,
    onChanged: (value) => onChanged(value ?? false),
  );
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, Responsive.buttonHeight(context)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.lightGrayGreen,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
