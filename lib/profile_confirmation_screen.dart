import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'loan_application_flow.dart';
import 'member_information_card.dart';
import 'app_theme.dart';
import 'loan_calculator_screen.dart';
import 'loan_calculator_service.dart';
import 'loan_application_mode.dart';

class ProfileConfirmationScreen extends StatefulWidget {
  final LoanType loanType;

  const ProfileConfirmationScreen({super.key, required this.loanType});

  @override
  State<ProfileConfirmationScreen> createState() =>
      _ProfileConfirmationScreenState();
}

class _ProfileConfirmationScreenState extends State<ProfileConfirmationScreen> {
  late final _flow = LoanApplicationFlow(
    widget.loanType,
    Supabase.instance.client,
    requireCoMaker: !loanParticipantsDemoBuild,
  );
  Map<String, dynamic>? _loadedApplicant;
  bool _attached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attached) return;
    final route = ModalRoute.of<void>(context);
    if (route != null) _flow.attach(route);
    _attached = true;
  }

  @override
  void dispose() {
    _flow.close(removeRoutes: false);
    super.dispose();
  }

  Future<void> _continueApplication() async {
    if (!_flow.isActive ||
        !_flow.draft.profileConfirmed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await _flow.push(context, (_) => LoanCalculatorScreen(flow: _flow));
  }

  @override
  Widget build(BuildContext context) {
    if (!_flow.isActive) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('Sign in to start a loan application.')),
      );
    }
    final draft = _flow.draft;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              const WarningBanner(),
              const SizedBox(height: AppTheme.spacingL),
              LiveMemberInformationCard(
                snapshot: draft.applicant,
                onLoaded: (member) {
                  if (_flow.isActive) setState(() => _loadedApplicant = member);
                },
              ),
              const SizedBox(height: AppTheme.spacingL),
              ConfirmationCard(
                isConfirmed: draft.profileConfirmed,
                onChanged: _loadedApplicant == null
                    ? null
                    : (value) {
                        final applicant = draft.applicant ?? _loadedApplicant;
                        if (!_flow.isActive || applicant == null) return;
                        setState(() {
                          draft.profileConfirmed = value ?? false;
                          draft.applicant = draft.profileConfirmed
                              ? Map<String, dynamic>.unmodifiable(applicant)
                              : null;
                        });
                      },
              ),
              const SizedBox(height: AppTheme.spacingL),
              PrimaryButton(
                label: _flow.participantsDemo
                    ? 'Proceed to Loan Application'
                    : 'Proceed to Loan Calculator',
                isEnabled: draft.profileConfirmed,
                onPressed: !draft.profileConfirmed
                    ? null
                    : _flow.participantsDemo
                    ? () => _flow.push(
                        context,
                        (_) => LoanCalculatorScreen(flow: _flow),
                      )
                    : _continueApplication,
              ),
              if (!_flow.participantsDemo) ...[
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  'Verify a co-maker, collect their consent, then submit your application for cooperative review.',
                  textAlign: TextAlign.center,
                  style: AppTheme.captionRegular,
                ),
              ],
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
        'Profile Confirmation',
        style: TextStyle(
          color: AppTheme.darkText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: const Color(0xFFE0C46B), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.accentGold,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              'Review the details from your registered member record before confirming. '
              'You can edit your name, contact number, and address in Profile. '
              'For other corrections, visit the CSUCC cooperative office. '
              'This application keeps the details you confirm here; start a new '
              'application to use updated details.',
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const ProfileInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF183A24),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationCard extends StatelessWidget {
  final bool isConfirmed;
  final ValueChanged<bool?>? onChanged;

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
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: AppTheme.cardShadow,
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
            child: Text(
              'I confirm that my profile information is accurate and up-to-date.',
              style: const TextStyle(
                color: AppTheme.primaryText,
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
  final String label;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.isEnabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
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
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
