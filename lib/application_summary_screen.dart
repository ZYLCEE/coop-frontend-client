import 'package:flutter/material.dart';
import 'member_information_card.dart';
import 'app_theme.dart';
import 'review_terms_screen.dart';
import 'loan_calculator_service.dart';
import 'models/loan_document.dart';

class ApplicationSummaryScreen extends StatefulWidget {
  final double loanAmount;
  final LoanType loanType;
  final int tenure;
  final LoanComputation computation;
  final String payslipFileName;
  final String idFileName;
  final String? collateralFileName;
  final String? otherFileName;
  final List<SelectedLoanDocument> documents;

  const ApplicationSummaryScreen({
    super.key,
    required this.loanAmount,
    required this.loanType,
    required this.tenure,
    required this.computation,
    required this.payslipFileName,
    required this.idFileName,
    this.collateralFileName,
    this.otherFileName,
    this.documents = const [],
  });

  @override
  State<ApplicationSummaryScreen> createState() =>
      _ApplicationSummaryScreenState();
}

class _ApplicationSummaryScreenState extends State<ApplicationSummaryScreen> {
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoanProgressIndicator(currentStep: 2),
              const SizedBox(height: AppTheme.spacingL),
              SummaryCard(
                loanAmount: widget.loanAmount,
                loanType: widget.loanType,
                tenure: widget.tenure,
                interestRate: widget.computation.interestRate,
              ),
              const SizedBox(height: AppTheme.spacingL),
              const MemberInformationCard(),
              const SizedBox(height: AppTheme.spacingL),
              LoanDetailsCard(
                loanType: widget.loanType,
                computation: widget.computation,
                tenure: widget.tenure,
              ),
              const SizedBox(height: AppTheme.spacingL),
              const DisbursementMethodCard(),
              const SizedBox(height: AppTheme.spacingL),
              DocumentsSubmittedCard(
                payslipFileName: widget.payslipFileName,
                idFileName: widget.idFileName,
                collateralFileName: widget.collateralFileName,
                otherFileName: widget.otherFileName,
              ),
              const SizedBox(height: AppTheme.spacingL),
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
                isEnabled: _isConfirmed,
                onPressed: _isConfirmed
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewTermsScreen(
                              loanAmount: widget.loanAmount,
                              loanType: widget.loanType.label,
                              tenure: widget.tenure,
                              documents: widget.documents,
                            ),
                          ),
                        );
                      }
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

class LoanProgressIndicator extends StatelessWidget {
  final int currentStep;

  const LoanProgressIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep('Loan Details', 0, currentStep),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 0
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
          ),
        ),
        _buildStep('Documents', 1, currentStep),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 1
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
          ),
        ),
        _buildStep('Review', 2, currentStep),
      ],
    );
  }

  Widget _buildStep(String label, int step, int currentStep) {
    final isActive = step == currentStep;
    final isCompleted = step < currentStep;

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
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
                  '${interestRate.toStringAsFixed(0)}%/mo',
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

class MemberInformationCard extends StatelessWidget {
  const MemberInformationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const LiveMemberInformationCard();
  }
}

class LoanDetailsCard extends StatelessWidget {
  final LoanType loanType;
  final LoanComputation computation;
  final int tenure;

  const LoanDetailsCard({
    super.key,
    required this.loanType,
    required this.computation,
    required this.tenure,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF183A24),
              fontSize: 13,
              fontWeight: FontWeight.w600,
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

class DisbursementMethodCard extends StatelessWidget {
  const DisbursementMethodCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISBURSEMENT METHOD',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              const Text(
                'Payout',
                style: TextStyle(
                  color: Color(0xFF7D8A82),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Text(
                  'Cheque',
                  style: const TextStyle(
                    color: Color(0xFF183A24),
                    fontSize: 14,
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
}

class DocumentsSubmittedCard extends StatelessWidget {
  final String payslipFileName;
  final String idFileName;
  final String? collateralFileName;
  final String? otherFileName;

  const DocumentsSubmittedCard({
    super.key,
    required this.payslipFileName,
    required this.idFileName,
    this.collateralFileName,
    this.otherFileName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DOCUMENTS SUBMITTED',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildDocumentRow('Pay Slip', payslipFileName),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildDocumentRow('Valid Identification', idFileName),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildDocumentRow('Collateral Document', collateralFileName),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          _buildDocumentRow('Other Supporting Documents', otherFileName),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String? fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              if (fileName != null) ...[
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Uploaded',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                Text(
                  'Not Submitted',
                  style: const TextStyle(
                    color: Color(0xFF7D8A82),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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

  const PrimaryButton({super.key, required this.isEnabled, this.onPressed});

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
        child: const Text(
          'Continue to Terms & Conditions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
