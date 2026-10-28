import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'loan_calculator_service.dart';
import 'documents_disbursement_screen.dart';
import 'models/loan_policy.dart';
import 'services/database_service.dart';
import 'application_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoanCalculatorScreen extends StatefulWidget {
  final LoanType? initialLoanType;

  const LoanCalculatorScreen({super.key, this.initialLoanType});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  late LoanType _selectedLoanType;
  double _loanAmount = 50000.0;
  int _selectedTenure = 12;
  late LoanComputation _computation;
  LoanPolicySettings? _policy;
  bool _policyLoading = true;
  String? _policyError;

  @override
  void initState() {
    super.initState();
    _selectedLoanType = widget.initialLoanType ?? LoanEligibility.defaultType;
    _computation = _calculateWith(
      const LoanPolicySettings(
        baseInterestRatePercent: 1.5,
        processingFeePercent: 1,
        serviceFeePercent: 0.5,
        minMemberTenureMonths: 6,
        minLoanAmount: 1000,
        maxLoanAmount: 500000,
        maxLoanMultiplier: 3,
        penaltyRatePercent: 2,
        coMakerRequiredAbove: 50000,
        collateralRequiredAbove: 200000,
        loanProcessingTime: '3–5',
      ),
    );
    _loadLoanPolicy();
  }

  Future<void> _loadLoanPolicy() async {
    setState(() {
      _policyLoading = true;
      _policyError = null;
    });
    try {
      final policy = await DatabaseService().getLoanPolicySettings();
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in to view current loan policies.');
      }
      final member = await DatabaseService().getMember(user.id);
      final joinedValue = member['date_joined'];
      final joined = joinedValue is String
          ? DateTime.tryParse(joinedValue)
          : null;
      if (joined == null) {
        throw StateError(
          'Unable to verify your membership date. Contact the cooperative admin.',
        );
      }
      final monthsAsMember =
          (DateTime.now().year - joined.year) * 12 +
          DateTime.now().month -
          joined.month -
          (DateTime.now().day < joined.day ? 1 : 0);
      if (monthsAsMember < policy.minMemberTenureMonths) {
        throw StateError(
          'Current loan policy requires at least ${policy.minMemberTenureMonths} months of membership. Your account does not meet this requirement yet.',
        );
      }
      ApplicationState.loanProcessingTime = policy.loanProcessingTime;
      setState(() {
        _policy = policy;
        _loanAmount = _loanAmount
            .clamp(policy.minLoanAmount, policy.maxLoanAmount)
            .toDouble();
        _computation = _calculateWith(policy);
        _policyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _policyError = error is StateError
            ? error.message
            : 'Unable to load current loan policy. Check your connection and retry.';
        _policyLoading = false;
      });
    }
  }

  LoanComputation _calculateWith(LoanPolicySettings policy) =>
      LoanCalculatorService().calculate(
        principal: _loanAmount
            .clamp(policy.minLoanAmount, policy.maxLoanAmount)
            .toDouble(),
        months: _selectedTenure,
        loanType: _selectedLoanType,
        baseInterestRatePercent: policy.baseInterestRatePercent,
        processingFeePercent: policy.processingFeePercent,
        serviceFeePercent: policy.serviceFeePercent,
      );

  void _updateComputation() {
    setState(() {
      _computation = _calculateWith(
        _policy ??
            const LoanPolicySettings(
              baseInterestRatePercent: 1.5,
              processingFeePercent: 1,
              serviceFeePercent: 0.5,
              minMemberTenureMonths: 6,
              minLoanAmount: 1000,
              maxLoanAmount: 500000,
              maxLoanMultiplier: 3,
              penaltyRatePercent: 2,
              coMakerRequiredAbove: 50000,
              collateralRequiredAbove: 200000,
              loanProcessingTime: '3–5',
            ),
      );
    });
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
              if (_policyLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              if (_policyError != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _policyError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _loadLoanPolicy,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_policy != null && _policyError == null) ...[
                const LoanProgressIndicator(currentStep: 0),
                const SizedBox(height: AppTheme.spacingL),
                LoanTypeDropdown(
                  selectedType: _selectedLoanType,
                  onChanged: (type) {
                    setState(() {
                      _selectedLoanType = type;
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                LoanAmountSlider(
                  amount: _loanAmount,
                  minimum: _policy!.minLoanAmount,
                  maximum: _policy!.maxLoanAmount,
                  onChanged: (value) {
                    setState(() {
                      _loanAmount = value
                          .clamp(_policy!.minLoanAmount, _policy!.maxLoanAmount)
                          .toDouble();
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                TenureSelector(
                  selectedTenure: _selectedTenure,
                  onChanged: (tenure) {
                    setState(() {
                      _selectedTenure = tenure;
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                LiveBreakdownCard(computation: _computation),
                const SizedBox(height: AppTheme.spacingL),
                PaymentScheduleCard(
                  computation: _computation,
                  months: _selectedTenure,
                ),
                const SizedBox(height: AppTheme.spacingXL),
                PrimaryButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentsDisbursementScreen(
                          loanAmount: _loanAmount,
                          loanType: _selectedLoanType,
                          tenure: _selectedTenure,
                          computation: _computation,
                          collateralRequiredAbove:
                              _policy!.collateralRequiredAbove,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacingXL),
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
        'Loan Calculator',
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

class LoanTypeDropdown extends StatelessWidget {
  final LoanType selectedType;
  final ValueChanged<LoanType> onChanged;

  const LoanTypeDropdown({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOAN TYPE',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InputDecorator(
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LoanType>(
                    value: selectedType,
                    isExpanded: true,
                    menuWidth: constraints.maxWidth,
                    menuMaxHeight: 280,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: AppTheme.cardWhite,
                    elevation: 4,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primaryGreen,
                    ),
                    items: LoanTypeCatalog.available.map((type) {
                      final isOngoing = LoanEligibility.isOngoing(type);
                      return DropdownMenuItem<LoanType>(
                        value: type,
                        enabled: !isOngoing,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            isOngoing
                                ? '${type.label} - Ongoing Loan'
                                : type.label,
                            style: TextStyle(
                              color: isOngoing
                                  ? AppTheme.mutedGray
                                  : const Color(0xFF183A24),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) onChanged(value);
                    },
                    style: const TextStyle(
                      color: Color(0xFF183A24),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LoanAmountSlider extends StatefulWidget {
  final double amount;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  const LoanAmountSlider({
    super.key,
    required this.amount,
    this.minimum = LoanCalculatorService.minLoanAmount,
    this.maximum = LoanCalculatorService.maxLoanAmount,
    required this.onChanged,
  });

  @override
  State<LoanAmountSlider> createState() => _LoanAmountSliderState();
}

class _LoanAmountSliderState extends State<LoanAmountSlider> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.amount.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(LoanAmountSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      final currentText = _controller.text;
      final newText = widget.amount.toStringAsFixed(0);
      if (currentText != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOAN AMOUNT',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₱',
                  prefixStyle: const TextStyle(
                    color: Color(0xFF183A24),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  suffixText: '.00',
                  suffixStyle: const TextStyle(
                    color: Color(0xFF183A24),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF183A24),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) {
                    final clamped = parsed.clamp(
                      widget.minimum,
                      widget.maximum,
                    );
                    widget.onChanged(clamped);
                  }
                },
                onEditingComplete: () {
                  final value = _controller.text;
                  final parsed = double.tryParse(value);
                  if (parsed == null) {
                    // Restore the current widget amount on invalid input
                    _controller.text = widget.amount.toStringAsFixed(0);
                  } else {
                    final clamped = parsed.clamp(
                      widget.minimum,
                      widget.maximum,
                    );
                    _controller.text = clamped.toStringAsFixed(0);
                    if (clamped != widget.amount) {
                      widget.onChanged(clamped);
                    }
                  }
                },
              ),
              const SizedBox(height: AppTheme.spacingL),
              Slider(
                value: widget.amount,
                min: widget.minimum,
                max: widget.maximum,
                divisions: ((widget.maximum - widget.minimum) / 1000)
                    .round()
                    .clamp(1, 1000),
                activeColor: AppTheme.primaryGreen,
                inactiveColor: const Color(0xFFE0E0E0),
                onChanged: widget.onChanged,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LoanCalculatorService.formatCurrency(widget.minimum),
                    style: const TextStyle(
                      color: Color(0xFF7D8A82),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Maximum ${LoanCalculatorService.formatCurrency(widget.maximum)}',
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    LoanCalculatorService.formatCurrency(widget.maximum),
                    style: const TextStyle(
                      color: Color(0xFF7D8A82),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TenureSelector extends StatelessWidget {
  final int selectedTenure;
  final ValueChanged<int> onChanged;

  const TenureSelector({
    super.key,
    required this.selectedTenure,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REPAYMENT TENURE',
          style: TextStyle(
            color: Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            _buildTenureButton('3mo', 3),
            const SizedBox(width: 8),
            _buildTenureButton('6mo', 6),
            const SizedBox(width: 8),
            _buildTenureButton('12mo', 12),
            const SizedBox(width: 8),
            _buildTenureButton('24mo', 24),
          ],
        ),
      ],
    );
  }

  Widget _buildTenureButton(String label, int tenure) {
    final isSelected = selectedTenure == tenure;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tenure),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : const Color(0xFFE8F0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF183A24),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class LiveBreakdownCard extends StatelessWidget {
  final LoanComputation computation;

  const LiveBreakdownCard({super.key, required this.computation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: const Color(0xFF1F6B3A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE BREAKDOWN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          BreakdownRow(
            label: 'Principal Amount',
            value: LoanCalculatorService.formatCurrency(computation.principal),
            isWhite: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Interest Rate',
            value: LoanCalculatorService.formatPercentage(
              computation.interestRate,
            ),
            isWhite: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Total Interest',
            value: LoanCalculatorService.formatCurrency(
              computation.totalInterest,
            ),
            isWhite: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Processing Fee',
            value:
                '-${LoanCalculatorService.formatCurrency(computation.processingFee)}',
            isWhite: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Notarial Fee',
            value:
                '-${LoanCalculatorService.formatCurrency(computation.notarialFee)}',
            isWhite: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Retention Fee (5%)',
            value:
                '-${LoanCalculatorService.formatCurrency(computation.retentionFee)}',
            isWhite: true,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF4A7A5A), thickness: 1),
          const SizedBox(height: 16),
          BreakdownRow(
            label: 'Net Take-Home',
            value: LoanCalculatorService.formatCurrency(
              computation.netTakeHome,
            ),
            isGold: true,
          ),
          const SizedBox(height: 12),
          BreakdownRow(
            label: 'Monthly Amortization',
            value: LoanCalculatorService.formatCurrency(
              computation.monthlyAmortization,
            ),
            isWhite: true,
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWhite;
  final bool isGold;
  final bool isBold;

  const BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.isWhite = false,
    this.isGold = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isGold ? AppTheme.accentGold : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGold ? AppTheme.accentGold : Colors.white,
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class PaymentScheduleCard extends StatelessWidget {
  final LoanComputation computation;
  final int months;

  const PaymentScheduleCard({
    super.key,
    required this.computation,
    required this.months,
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
            'PAYMENT SCHEDULE',
            style: TextStyle(
              color: Color(0xFF7D8A82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            height: 300,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: months,
              itemBuilder: (context, index) {
                return PaymentScheduleItem(
                  month: index + 1,
                  date: computation.paymentDates[index],
                  amount: computation.monthlyAmortization,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentScheduleItem extends StatelessWidget {
  final int month;
  final DateTime date;
  final double amount;

  const PaymentScheduleItem({
    super.key,
    required this.month,
    required this.date,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'Month $month',
              style: const TextStyle(
                color: Color(0xFF7D8A82),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dateFormat.format(date),
              style: const TextStyle(
                color: Color(0xFF183A24),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            LoanCalculatorService.formatCurrency(amount),
            style: const TextStyle(
              color: Color(0xFF183A24),
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
          'Apply Now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
