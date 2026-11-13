import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../loan_calculator_service.dart';
import '../models/loan_agreement_snapshot.dart';
import '../models/loan_document.dart';
import '../member_information_card.dart';

class LoanReviewSection extends StatelessWidget {
  const LoanReviewSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppTheme.spacingL),
    decoration: BoxDecoration(
      color: AppTheme.cardWhite,
      borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.titleBold),
        const SizedBox(height: AppTheme.spacingM),
        ...children,
      ],
    ),
  );
}

class LoanParticipantReviewCard extends StatelessWidget {
  const LoanParticipantReviewCard({
    super.key,
    required this.snapshot,
    this.localPreview = false,
  });

  final LoanAgreementSnapshot snapshot;
  final bool localPreview;

  @override
  Widget build(BuildContext context) {
    final coMaker = snapshot.coMaker;
    return LoanReviewSection(
      title: 'Participant Information',
      children: [
        Text(
          localPreview
              ? 'Local draft information'
              : snapshot.participantsDemo
              ? 'Demonstration selections'
              : 'Verified member information',
          style: AppTheme.captionBold,
        ),
        const SizedBox(height: AppTheme.spacingM),
        const Text('Co-Maker', style: AppTheme.bodyBold),
        if (coMaker == null)
          const Text('No selection', style: AppTheme.bodyRegular)
        else ...[
          Text(
            '${coMaker.name} (${coMaker.memberId})',
            style: AppTheme.bodyRegular,
          ),
          Text(
            'Relationship to borrower: ${snapshot.relationship}',
            style: AppTheme.bodyRegular,
          ),
          if (snapshot.coMakerIdDocumentName != null)
            Text(
              'Co-maker ID document: ${snapshot.coMakerIdDocumentName}',
              style: AppTheme.bodyRegular,
            ),
          Text(
            localPreview
                ? 'Local draft only. No invitation or consent has been recorded.'
                : snapshot.participantsDemo
                ? 'Fictional demo selection. This is not a real member consent.'
                : 'Member lookup confirmed. Co-maker consent is required before submission.',
            style: AppTheme.captionRegular,
          ),
        ],
        const SizedBox(height: AppTheme.spacingM),
        _witness('Witness 1', snapshot.witnessOne),
        const SizedBox(height: AppTheme.spacingS),
        _witness('Witness 2', snapshot.witnessTwo),
      ],
    );
  }

  Widget _witness(String label, String name) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.bodyBold),
      Text(
        name.isEmpty ? 'No name entered' : name,
        style: AppTheme.bodyRegular,
      ),
    ],
  );
}

class LoanAgreementPreview extends StatelessWidget {
  const LoanAgreementPreview({
    super.key,
    required this.snapshot,
    this.showApplicantDetails = true,
    this.fictionalBorrowerName,
    this.localPreview = false,
  });

  final LoanAgreementSnapshot snapshot;
  final bool showApplicantDetails;
  final String? fictionalBorrowerName;
  final bool localPreview;

  String get _borrowerName =>
      [snapshot.applicant['first_name'], snapshot.applicant['last_name']]
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .join(' ');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LoanReviewSection(
        title: 'Application Details',
        children: [
          Text(
            localPreview
                ? 'CSUCC paper form outline · Local draft estimates'
                : snapshot.participantsDemo
                ? 'CSUCC paper form outline · Draft estimates for demonstration'
                : 'CSUCC paper form outline · Proposed application for cooperative review',
            style: AppTheme.captionBold,
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (showApplicantDetails && _borrowerName.isNotEmpty)
            Text('Borrower: $_borrowerName', style: AppTheme.bodyRegular),
          if (fictionalBorrowerName case final name?)
            Text('Borrower: $name', style: AppTheme.bodyRegular),
          Text(snapshot.loanType.label, style: AppTheme.bodyBold),
          if (snapshot.applicationKind case final kind?)
            Text('${kind.label} (draft only)', style: AppTheme.bodyRegular),
          Text(
            'Requested amount: ${LoanCalculatorService.formatCurrency(snapshot.amount)}',
            style: AppTheme.bodyRegular,
          ),
          Text(
            'Repayment tenure: ${snapshot.tenure} months',
            style: AppTheme.bodyRegular,
          ),
          Text(
            'Interest rate: ${LoanCalculatorService.formatPercentage(snapshot.computation.interestRate)}',
            style: AppTheme.bodyRegular,
          ),
          for (final (label, value) in [
            (
              fictionalBorrowerName == null
                  ? 'Total interest'
                  : 'Total estimated interest',
              snapshot.computation.totalInterest,
            ),
            ('Processing fee', snapshot.computation.processingFee),
            ('Notarial fee', snapshot.computation.notarialFee),
            ('Retention fee', snapshot.computation.retentionFee),
            ('Net take-home', snapshot.computation.netTakeHome),
          ])
            Text(
              '$label: ${LoanCalculatorService.formatCurrency(value)}',
              style: AppTheme.bodyRegular,
            ),
          Text(
            'Estimated monthly amortization: ${LoanCalculatorService.formatCurrency(snapshot.computation.monthlyAmortization)}',
            style: AppTheme.bodyRegular,
          ),
        ],
      ),
      if (fictionalBorrowerName != null) ...[
        const SizedBox(height: AppTheme.spacingL),
        LoanReviewSection(
          title: 'Estimated Repayment Schedule',
          children: [
            Text(
              'Total estimated repayment: ${LoanCalculatorService.formatCurrency(snapshot.computation.monthlyAmortization * snapshot.tenure)}',
              style: AppTheme.bodyBold,
            ),
            const Text(
              'These are draft installments. The cooperative has yet to confirm the repayment schedule.',
              style: AppTheme.captionRegular,
            ),
            for (final (index, date) in snapshot.repaymentDates.indexed)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                child: Text(
                  'Installment ${index + 1} · ${DateFormat.yMMMd().format(date)} · '
                  '${LoanCalculatorService.formatCurrency(snapshot.computation.monthlyAmortization)}',
                  style: AppTheme.bodyRegular,
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: AppTheme.spacingL),
      if (showApplicantDetails) ...[
        LiveMemberInformationCard(snapshot: snapshot.applicant),
        const SizedBox(height: AppTheme.spacingL),
        LoanParticipantReviewCard(
          snapshot: snapshot,
          localPreview: localPreview,
        ),
        const SizedBox(height: AppTheme.spacingL),
        SelectedDocumentsCard(snapshot: snapshot),
        const SizedBox(height: AppTheme.spacingL),
      ],
      const LoanReviewSection(
        title: 'Agreement and Promissory Note',
        children: [
          Text(
            'Application / Agreement wording and the Promissory Note await an approved digital template.',
            style: AppTheme.bodyRegular,
          ),
          SizedBox(height: AppTheme.spacingM),
          Text('Terms and Conditions', style: AppTheme.bodyBold),
          Text(
            'Approved wording for this digital preview is pending.',
            style: AppTheme.bodyRegular,
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingL),
      const LoanReviewSection(
        title: 'Outstanding Certifications and Formalities',
        children: [
          Text('Employer Certification', style: AppTheme.bodyBold),
          Text(
            'Certification by an authorized employer representative is pending.',
            style: AppTheme.bodyRegular,
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Borrower and co-maker signatures, separate witness attestations, and notarial acknowledgment remain pending.',
            style: AppTheme.bodyRegular,
          ),
        ],
      ),
    ],
  );
}

class SelectedDocumentsCard extends StatelessWidget {
  const SelectedDocumentsCard({super.key, required this.snapshot});

  final LoanAgreementSnapshot snapshot;

  @override
  Widget build(BuildContext context) => LoanReviewSection(
    title: 'Selected Documents',
    children: [
      for (final kind in snapshot.visibleDocumentKinds) ...[
        if (kind != LoanDocumentKind.values.first) const Divider(),
        Text(
          '${kind.label} · ${snapshot.requiresDocument(kind) ? (snapshot.participantsDemo && kind == LoanDocumentKind.collateral ? 'Required in demo' : 'Required') : 'Optional'}',
          style: AppTheme.bodyBold,
        ),
        if (snapshot.documents[kind] case final file?)
          Text(
            '${file.name} (${file.extension.toUpperCase()}) · Selected locally',
            style: AppTheme.bodyRegular,
          )
        else
          const Text('No file selected', style: AppTheme.captionRegular),
      ],
    ],
  );
}
