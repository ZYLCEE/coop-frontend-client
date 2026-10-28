import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'application_service.dart';
import 'services/supabase_service.dart';
import 'services/database_service.dart';
import 'models/loan_document.dart';
import 'loan_application_submitted_screen.dart';

String maskEmailAddress(String email) {
  final normalized = email.trim();
  final separator = normalized.lastIndexOf('@');
  if (separator <= 0 || separator == normalized.length - 1)
    return 'unavailable';
  final local = normalized.substring(0, separator);
  final domain = normalized.substring(separator + 1);
  final visible = local.substring(0, 1);
  final hidden = List.filled((local.length - 1).clamp(3, 12), '•').join();
  return '$visible$hidden@$domain';
}

class EmailOtpVerificationScreen extends StatefulWidget {
  final double loanAmount;
  final String loanType;
  final int tenure;
  final List<SelectedLoanDocument> documents;

  const EmailOtpVerificationScreen({
    super.key,
    required this.loanAmount,
    required this.loanType,
    this.tenure = 12,
    this.documents = const [],
  });

  @override
  State<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends State<EmailOtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    8,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(8, (index) => FocusNode());

  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isEmailVerified = false;
  String? _referenceNumber;
  String? _submissionStatus;
  String? _verifiedEmail;
  String? _emailError;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _sendInitialOtp();
  }

  Future<void> _sendInitialOtp() async {
    try {
      final email = await _loadVerifiedRegisteredEmail();
      if (email == null) return;
      await SupabaseService().sendOtp(email: email);
      if (mounted) {
        setState(() => _otpSent = true);
        _startResendTimer();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
        _emailError = error is StateError
            ? error.message
            : 'Unable to send a verification code to the registered email.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send the verification code. Tap Resend to try again.',
          ),
        ),
      );
    }
  }

  Future<String?> _loadVerifiedRegisteredEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    final authEmail = user?.email?.trim();
    if (user == null || authEmail == null || authEmail.isEmpty) {
      throw StateError(
        'Your login session has no registered email. Sign out and contact the cooperative admin.',
      );
    }
    final member = await DatabaseService().getMember(user.id);
    final profileEmail = member['email']?.toString().trim() ?? '';
    if (profileEmail.isEmpty ||
        profileEmail.toLowerCase() != authEmail.toLowerCase()) {
      if (mounted)
        setState(
          () => _emailError =
              'Your profile email does not match your login email. Contact the cooperative admin to correct it before verifying.',
        );
      return null;
    }
    if (mounted)
      setState(() {
        _verifiedEmail = authEmail;
        _emailError = null;
      });
    return authEmail;
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _remainingSeconds = 60;
      _canResend = false;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        setState(() {
          _canResend = true;
        });
        return false;
      }
      return true;
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpControllers.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_isOtpComplete()) {
      _focusNodes[index].unfocus();
    }
  }

  bool _isOtpComplete() {
    return _otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  String _getOtpValue() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _clearOtp({bool requestFocus = true}) {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    if (requestFocus) {
      _focusNodes[0].requestFocus();
    }
  }

  void _handleResend() async {
    if (!_canResend) return;

    try {
      final email = _verifiedEmail ?? await _loadVerifiedRegisteredEmail();
      if (email == null) return;
      await SupabaseService().sendOtp(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A new verification code has been sent to your registered email.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        setState(() => _otpSent = true);
        _startResendTimer();
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : error.toString().toLowerCase().contains(
                    'retryablefetchexception',
                  ) ||
                  error.toString().toLowerCase().contains('failed to fetch')
            ? 'Cannot connect to Supabase Auth. Check your internet connection, then try again.'
            : 'Unable to resend the verification code. Check your email settings or try again later.';
        setState(() => _emailError = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleVerify() async {
    if (!_isOtpComplete() || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _submissionStatus = _isEmailVerified
          ? 'Preparing documents...'
          : 'Verifying code...';
    });

    final otp = _getOtpValue();

    try {
      if (!_isEmailVerified) {
        final email = _verifiedEmail ?? await _loadVerifiedRegisteredEmail();
        if (email == null)
          throw StateError(
            _emailError ?? 'The registered email could not be verified.',
          );
        await SupabaseService().verifyOtp(email: email, token: otp);
        _isEmailVerified = true;
      }

      _referenceNumber ??= ApplicationService.generateReferenceNumber();
      await DatabaseService().submitLoanApplication(
        applicationId: _referenceNumber!,
        loanType: widget.loanType,
        amount: widget.loanAmount,
        documents: widget.documents,
        tenureMonths: widget.tenure,
        onProgress: (status) {
          if (mounted) setState(() => _submissionStatus = status);
        },
      );

      if (mounted) {
        _clearOtp(requestFocus: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoanApplicationSubmittedScreen(
              referenceNumber: _referenceNumber!,
              submissionDateTime: ApplicationService.formatSubmissionDateTime(),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEmailVerified
                  ? 'Application could not be submitted: ${error is StateError ? error.message : 'Please check your connection and retry.'}'
                  : 'Invalid verification code. Please try again.',
            ),
            backgroundColor: Color(0xFFD9534F),
          ),
        );
        if (!_isEmailVerified) _clearOtp();
      }
    }
  }

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
            children: [
              const LoanProgressIndicator(currentStep: 2),
              const SizedBox(height: AppTheme.spacingXL),
              VerificationHeader(
                maskedEmail: _verifiedEmail == null
                    ? null
                    : maskEmailAddress(_verifiedEmail!),
                error: _emailError,
                codeSent: _otpSent,
              ),
              if (_submissionStatus != null && _isVerifying)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _submissionStatus!,
                    style: const TextStyle(color: AppTheme.primaryGreen),
                  ),
                ),
              const SizedBox(height: AppTheme.spacingXL),
              OtpInputFields(
                controllers: _otpControllers,
                focusNodes: _focusNodes,
                onChanged: _onOtpChanged,
              ),
              const SizedBox(height: AppTheme.spacingL),
              OtpTimer(
                remainingSeconds: _remainingSeconds,
                canResend: _canResend,
                onResend: _handleResend,
              ),
              const SizedBox(height: AppTheme.spacingXL),
              PrimaryButton(
                isEnabled: _isOtpComplete() && !_isVerifying,
                onPressed: _handleVerify,
                isLoading: _isVerifying,
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Text(
                'For your security, never share your OTP with anyone.',
                style: TextStyle(
                  color: Color(0xFF7D8A82),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
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
        'Verify Application',
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

class VerificationHeader extends StatelessWidget {
  const VerificationHeader({
    super.key,
    this.maskedEmail,
    this.error,
    this.codeSent = false,
  });
  final String? maskedEmail;
  final String? error;
  final bool codeSent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F3EC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: AppTheme.primaryGreen,
            size: 40,
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        const Text(
          'Email Verification',
          style: TextStyle(
            color: Color(0xFF183A24),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          codeSent
              ? 'An 8-digit verification code was sent to your registered email.'
              : 'We will send a verification code to the email registered to your account.',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          maskedEmail ?? 'Email address unavailable',
          style: TextStyle(
            color: Color(0xFF183A24),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingS),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class OtpInputFields extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Function(int, String) onChanged;

  const OtpInputFields({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const fieldCount = 8;
        const fieldPadding = 4.0;
        final fieldWidth =
            ((constraints.maxWidth - fieldCount * fieldPadding * 2) /
                    fieldCount)
                .clamp(28.0, 44.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            fieldCount,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: fieldPadding),
              child: SizedBox(
                width: fieldWidth,
                height: 56,
                child: TextField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF183A24),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryGreen,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                  ),
                  onChanged: (value) => onChanged(index, value),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OtpTimer extends StatelessWidget {
  final int remainingSeconds;
  final bool canResend;
  final VoidCallback onResend;

  const OtpTimer({
    super.key,
    required this.remainingSeconds,
    required this.canResend,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        const Text(
          'Didn\'t receive the code?',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        GestureDetector(
          onTap: canResend ? onResend : null,
          child: Text(
            canResend ? 'Resend Code' : 'Resend Code in $timeString',
            style: TextStyle(
              color: canResend
                  ? AppTheme.primaryGreen
                  : const Color(0xFF7D8A82),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: canResend
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.isEnabled,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
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
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Verify OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
