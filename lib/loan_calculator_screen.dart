import 'loan_application_flow.dart';
import 'widgets/loan_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'loan_calculator_service.dart';
import 'documents_disbursement_screen.dart';
import 'loan_participants_screen.dart';
import 'models/loan_policy.dart';
import 'models/loan_application_draft.dart';
import 'services/database_service.dart';
import 'application_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoanCalculatorScreen extends StatefulWidget {
  final LoanApplicationFlow flow;

  const LoanCalculatorScreen({super.key, required this.flow});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  late final _draft = widget.flow.draft;
  bool _policyLoading = true;
  String? _policyError;
  Set<LoanType> _blockedLoanTypes = const {};

  @override
  void initState() {
    super.initState();
    if (_draft.policy == null) {
      _loadLoanPolicy();
    } else {
      _policyLoading = false;
    }
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
      final loans = await DatabaseService().getLoanApplications(user.id);
      final blockedTypes = LoanTypeCatalog.available
          .where(
            (type) => LoanEligibility.blockingApplication(type, loans) != null,
          )
          .toSet();
      if (!mounted || !widget.flow.isActive) return;
      ApplicationState.loanProcessingTime = policy.loanProcessingTime;
      setState(() {
        _draft.policy = policy;
        _blockedLoanTypes = blockedTypes;
        if (blockedTypes.contains(_draft.loanType)) {
          _draft.loanType = LoanTypeCatalog.available.firstWhere(
            (type) => !blockedTypes.contains(type),
            orElse: () => _draft.loanType,
          );
        }
        _draft.amount = _draft.amount
            .clamp(policy.minLoanAmount, policy.maxLoanAmount)
            .toDouble();
        _draft.computation = _calculateWith(policy);
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
        principal: _draft.amount
            .clamp(policy.minLoanAmount, policy.maxLoanAmount)
            .toDouble(),
        months: _draft.tenure,
        loanType: _draft.loanType,
        baseInterestRatePercent: policy.baseInterestRatePercent,
        processingFeePercent: policy.processingFeePercent,
        serviceFeePercent: policy.serviceFeePercent,
      );

  void _updateComputation() {
    _draft.computation = _calculateWith(_draft.policy!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                          style: const TextStyle(color: AppTheme.danger),
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
              if (_draft.policy != null && _policyError == null) ...[
                LoanProgressIndicator.forApplication(
                  LoanApplicationStep.details,
                  participantsDemo: widget.flow.participantsDemo,
                  previewOnly: widget.flow.previewOnly,
                  hasParticipants: widget.flow.hasParticipantsStep,
                ),
                const SizedBox(height: AppTheme.spacingL),
                LoanTypeDropdown(
                  selectedType: _draft.loanType,
                  blockedTypes: _blockedLoanTypes,
                  onChanged: (type) {
                    setState(() {
                      _draft.loanType = type;
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                _LoanOptionSelector<LoanApplicationKind>(
                  label: 'APPLICATION TYPE',
                  choices: {
                    for (final kind in LoanApplicationKind.values)
                      kind: kind.label,
                  },
                  selected: _draft.applicationKind,
                  onChanged: (kind) => setState(() {
                    _draft.applicationKind = _draft.applicationKind == kind
                        ? null
                        : kind;
                  }),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  'Optional for this draft. This choice is not sent with the application.',
                  style: AppTheme.captionRegular,
                ),
                const SizedBox(height: AppTheme.spacingL),
                LoanAmountSlider(
                  amount: _draft.amount,
                  minimum: _draft.policy!.minLoanAmount,
                  maximum: _draft.policy!.maxLoanAmount,
                  onChanged: (value) {
                    setState(() {
                      _draft.amount = value
                          .clamp(
                            _draft.policy!.minLoanAmount,
                            _draft.policy!.maxLoanAmount,
                          )
                          .toDouble();
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                TenureSelector(
                  selectedTenure: _draft.tenure,
                  onChanged: (tenure) {
                    setState(() {
                      _draft.tenure = tenure;
                      _updateComputation();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                LiveBreakdownCard(computation: _draft.computation!),
                const SizedBox(height: AppTheme.spacingL),
                PaymentScheduleCard(
                  computation: _draft.computation!,
                  months: _draft.tenure,
                ),
                const SizedBox(height: AppTheme.spacingXL),
                PrimaryButton(
                  label: widget.flow.hasParticipantsStep
                      ? 'Continue to Participants'
                      : 'Apply Now',
                  onPressed: _blockedLoanTypes.contains(_draft.loanType)
                      ? null
                      : () {
                          widget.flow.push(
                            context,
                            (_) => widget.flow.hasParticipantsStep
                                ? LoanParticipantsScreen(flow: widget.flow)
                                : DocumentsDisbursementScreen.forFlow(
                                    widget.flow,
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

class LoanTypeDropdown extends StatelessWidget {
  final LoanType selectedType;
  final Set<LoanType> blockedTypes;
  final ValueChanged<LoanType> onChanged;

  const LoanTypeDropdown({
    super.key,
    required this.selectedType,
    required this.blockedTypes,
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
                      final isOngoing = blockedTypes.contains(type);
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
                  if (parsed != null && parsed.isFinite) {
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
                  if (parsed == null || !parsed.isFinite) {
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
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingXS,
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
  Widget build(BuildContext context) => _LoanOptionSelector<int>(
    label: 'REPAYMENT TENURE',
    choices: const {3: '3mo', 6: '6mo', 12: '12mo', 24: '24mo'},
    selected: selectedTenure,
    onChanged: onChanged,
  );
}

class _LoanOptionSelector<T> extends StatelessWidget {
  const _LoanOptionSelector({
    required this.label,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Map<T, String> choices;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: AppTheme.spacingM),
        Row(
          spacing: AppTheme.spacingS,
          children: [
            for (final choice in choices.entries) _buildChoice(choice),
          ],
        ),
      ],
    );
  }

  Widget _buildChoice(MapEntry<T, String> choice) {
    final isSelected = selected == choice.key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(choice.key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : const Color(0xFFE8F0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            choice.value,
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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppTheme.spacingS,
        runSpacing: AppTheme.spacingXS,
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
      ),
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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    this.label = 'Apply Now',
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
          backgroundColor: AppTheme.primaryGreen,
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
