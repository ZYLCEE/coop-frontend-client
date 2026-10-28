import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'dashboard.dart';
import 'application_service.dart';
import 'application_state.dart';

class LoanApplicationSubmittedScreen extends StatefulWidget {
  final String referenceNumber;
  final String submissionDateTime;

  const LoanApplicationSubmittedScreen({
    super.key,
    required this.referenceNumber,
    required this.submissionDateTime,
  });

  @override
  State<LoanApplicationSubmittedScreen> createState() =>
      _LoanApplicationSubmittedScreenState();
}

class _LoanApplicationSubmittedScreenState
    extends State<LoanApplicationSubmittedScreen> {
  @override
  void initState() {
    super.initState();
    _setPendingApplication();
  }

  Future<void> _setPendingApplication() async {
    ApplicationState.setPendingApplication(true);
  }

  @override
  Widget build(BuildContext context) {
    final processingTime = ApplicationService.getExpectedProcessingTime();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spacingXL),
              const SuccessHeader(),
              const SizedBox(height: AppTheme.spacingXL),
              ReferenceCard(
                referenceNumber: widget.referenceNumber,
                submissionDateTime: widget.submissionDateTime,
              ),
              const SizedBox(height: AppTheme.spacingL),
              ProcessingTimeCard(processingTime: processingTime),
              const SizedBox(height: AppTheme.spacingXL),
              const NextStepsCard(),
              const SizedBox(height: AppTheme.spacingXL),
              PrimaryButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const Dashboard()),
                    (route) => false,
                  );
                },
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
      title: const Text(
        'Application Submitted',
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

class SuccessHeader extends StatelessWidget {
  const SuccessHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
        ),
        const SizedBox(height: AppTheme.spacingL),
        const Text(
          'Loan Application Submitted',
          style: TextStyle(
            color: Color(0xFF183A24),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingM),
        const Text(
          'Your application has been successfully submitted for review.',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ReferenceCard extends StatelessWidget {
  final String referenceNumber;
  final String submissionDateTime;

  const ReferenceCard({
    super.key,
    required this.referenceNumber,
    required this.submissionDateTime,
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
            'Reference No.',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            referenceNumber,
            style: const TextStyle(
              color: Color(0xFF183A24),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          const Divider(color: Color(0xFFE6E6E6), thickness: 1),
          const SizedBox(height: AppTheme.spacingM),
          const Text(
            'Submitted On',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            submissionDateTime,
            style: const TextStyle(
              color: Color(0xFF183A24),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingTimeCard extends StatelessWidget {
  final String processingTime;

  const ProcessingTimeCard({super.key, required this.processingTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_outlined,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expected Processing Time',
                  style: TextStyle(
                    color: Color(0xFF7D8A82),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  processingTime,
                  style: const TextStyle(
                    color: Color(0xFF183A24),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NextStepsCard extends StatelessWidget {
  const NextStepsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What happens next?',
          style: TextStyle(
            color: Color(0xFF183A24),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildNextStepRow(
                Icons.assignment_outlined,
                'Your application is now under review by the cooperative.',
              ),
              const Divider(color: Color(0xFFE6E6E6), thickness: 1),
              _buildNextStepRow(
                Icons.verified_user_outlined,
                'We will verify your submitted documents and application details.',
              ),
              const Divider(color: Color(0xFFE6E6E6), thickness: 1),
              _buildNextStepRow(
                Icons.notifications_none,
                'You\'ll receive a notification once a decision has been made.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStepRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF183A24),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Return to Dashboard',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
