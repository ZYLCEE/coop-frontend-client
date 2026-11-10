import 'loan_application_flow.dart';
import 'widgets/loan_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'member_information_card.dart';
import 'app_theme.dart';
import 'review_terms_screen.dart';
import 'loan_calculator_service.dart';
import 'models/loan_agreement_snapshot.dart';
import 'widgets/loan_agreement_preview.dart';

class ApplicationSummaryScreen extends StatefulWidget {
  final LoanApplicationFlow flow;

  const ApplicationSummaryScreen({super.key, required this.flow});

  @override
  State<ApplicationSummaryScreen> createState() =>
      _ApplicationSummaryScreenState();
}

class _ApplicationSummaryScreenState extends State<ApplicationSummaryScreen> {
  bool _isConfirmed = false;
  late final _snapshot = LoanAgreementSnapshot.fromDraft(
    widget.flow.draft,
    participantsDemo: widget.flow.participantsDemo,
  );

  @override
  Widget build(BuildContext context) {
    final computation = _snapshot.computation;
    final usesParticipantWorkflow = widget.flow.hasParticipantsStep;
    final usesPreview = widget.flow.previewOnly || widget.flow.participantsDemo;
    final canContinue = _isConfirmed || usesPreview;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LoanProgressIndicator.forApplication(
                LoanApplicationStep.review,
                participantsDemo: widget.flow.participantsDemo,
                previewOnly: widget.flow.previewOnly,
                hasParticipants: widget.flow.hasParticipantsStep,
              ),
              const SizedBox(height: AppTheme.spacingL),
              SummaryCard(
                loanAmount: _snapshot.amount,
                loanType: _snapshot.loanType,
                tenure: _snapshot.tenure,
                interestRate: computation.interestRate,
              ),
              const SizedBox(height: AppTheme.spacingL),
              LiveMemberInformationCard(snapshot: _snapshot.applicant),
              const SizedBox(height: AppTheme.spacingL),
              LoanDetailsCard(
                loanType: _snapshot.loanType,
                computation: computation,
                tenure: _snapshot.tenure,
                applicationKindLabel: _snapshot.applicationKind?.label,
              ),
              const SizedBox(height: AppTheme.spacingL),
              if (usesParticipantWorkflow) ...[
                LoanParticipantReviewCard(
                  snapshot: _snapshot,
                  localPreview: widget.flow.previewOnly,
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],
              SelectedDocumentsCard(snapshot: _snapshot),
              const SizedBox(height: AppTheme.spacingL),
              if (!usesPreview)
                ConfirmationCard(
                  isConfirmed: _isConfirmed,
                  onChanged: (value) {
                    setState(() {
                      _isConfirmed = value ?? false;
                    });
                  },
                ),
              const SizedBox(height: AppTheme.spacingXL),
              PrimaryButton(
                label: usesPreview
                    ? 'Preview Agreement and Terms'
                    : 'Continue to Terms & Conditions',
                isEnabled: canContinue,
                onPressed: canContinue
                    ? () => widget.flow.push(
                        context,
                        (_) => ReviewTermsScreen(
                          flow: widget.flow,
                          snapshot: _snapshot,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      title: const Text(
        'Application Summary',
        style: TextStyle(
          color: Color(0xFF183A24),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }
}

class SummaryCard extends StatelessWidget {
  final double loanAmount;
  final LoanType loanType;
  final int tenure;
  final double interestRate;

  const SummaryCard({
    super.key,
    required this.loanAmount,
    required this.loanType,
    required this.tenure,
    required this.interestRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL LOAN REQUESTED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            LoanCalculatorService.formatCurrency(loanAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getLoanTypeLabel(loanType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$tenure months',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LoanCalculatorService.formatPercentage(
                    interestRate,
                    compact: true,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLoanTypeLabel(LoanType type) {
    return type.label;
  }
}

class LoanDetailsCard extends StatelessWidget {
  final LoanType loanType;
  final LoanComputation computation;
  final int tenure;

  final String? applicationKindLabel;

  const LoanDetailsCard({
    super.key,
    required this.loanType,
    required this.computation,
    required this.tenure,
    this.applicationKindLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LOAN DETAILS',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoRow('Loan Type', _getLoanTypeLabel(loanType)),
          if (applicationKindLabel != null) ...[
            const Divider(color: Color(0xFFE6E6E6), thickness: 1),
            _buildInfoRow(
              'Application Type',
              '$applicationKindLabel (draft only)',
            ),
          ],
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow(
            'Principal Amount',
            LoanCalculatorService.formatCurrency(computation.principal),
          ),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow('Repayment Tenure', '$tenure months'),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow(
            'Monthly Interest',
            LoanCalculatorService.formatPercentage(computation.interestRate),
          ),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow(
            'Total Interest',
            LoanCalculatorService.formatCurrency(computation.totalInterest),
          ),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          for (final fee in [
            ('Processing Fee', computation.processingFee),
            ('Notarial Fee', computation.notarialFee),
            ('Retention Fee', computation.retentionFee),
          ]) ...[
            _buildInfoRow(fee.$1, LoanCalculatorService.formatCurrency(fee.$2)),
            const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          ],
          _buildInfoRow(
            'Total Deductions',
            LoanCalculatorService.formatCurrency(
              computation.processingFee +
                  computation.notarialFee +
                  computation.retentionFee,
            ),
          ),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow(
            'Net Take-Home',
            LoanCalculatorService.formatCurrency(computation.netTakeHome),
          ),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildInfoRow(
            'Monthly Amortization',
            LoanCalculatorService.formatCurrency(
              computation.monthlyAmortization,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.captionRegular)),
          const SizedBox(width: AppTheme.spacingS),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppTheme.captionBold.copyWith(
                  color: AppTheme.primaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLoanTypeLabel(LoanType type) {
    return type.label;
  }
}

class ConfirmationCard extends StatelessWidget {
  final bool isConfirmed;
  final ValueChanged<bool?> onChanged;

  const ConfirmationCard({
    super.key,
    required this.isConfirmed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isConfirmed,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text:
                        'By submitting, you confirm that all information is accurate and authorize ',
                    style: TextStyle(color: Color(0xFF183A24)),
                  ),
                  const TextSpan(
                    text: 'CSUCC',
                    style: TextStyle(color: Color(0xFFFFD817)),
                  ),
                  const TextSpan(
                    text: 'ERMPC',
                    style: TextStyle(color: Colors.white),
                  ),
                  const TextSpan(
                    text: ' to process your loan application.',
                    style: TextStyle(color: Color(0xFF183A24)),
                  ),
                ],
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.isEnabled,
    this.onPressed,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppTheme.primaryGreen
              : const Color(0xFFB8C4B8),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
