import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'services/database_service.dart';
import 'package:intl/intl.dart';

class Loan {
  final String id;
  final String loanType;
  final String principal;
  final String disbursementDate;
  final List<PaymentSchedule> amortizationSchedule;
  final String status;
  final double actualAmountPaid;

  Loan({
    required this.id,
    required this.loanType,
    required this.principal,
    required this.disbursementDate,
    required this.amortizationSchedule,
    this.status = 'released',
    this.actualAmountPaid = 0,
  });

  double get principalAmount => _parseCurrency(principal);

  String get monthlyPayment => amortizationSchedule.isEmpty
      ? 'Not recorded'
      : amortizationSchedule.first.amount;

  double get totalRepayable => _amountFor(amortizationSchedule);

  double get amountPaid => actualAmountPaid;

  double get outstandingBalance =>
      (totalRepayable - amountPaid).clamp(0.0, double.infinity);

  double get totalInterest => totalRepayable - principalAmount;

  double get interestPaid =>
      totalRepayable == 0 ? 0 : totalInterest * amountPaid / totalRepayable;

  int get remainingMonths => amortizationSchedule
      .where((payment) => payment.status != PaymentStatus.completed)
      .length;

  int get totalMonths => amortizationSchedule.length;

  double get paymentProgress =>
      totalRepayable == 0 ? 0 : (amountPaid / totalRepayable).clamp(0, 1);

  factory Loan.fromDatabase(Map<String, dynamic> row) {
    final releasedDate = DateTime.tryParse('${row['date_released'] ?? ''}');
    final principal = double.tryParse('${row['amount'] ?? ''}') ?? 0;
    final monthly = double.tryParse('${row['monthly_payment'] ?? ''}');
    final tenure = int.tryParse('${row['tenure_months'] ?? ''}') ?? 0;
    final rawPayments = row['loan_payments'];
    final payments = rawPayments is List
        ? rawPayments
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final actualPaid = payments.fold<double>(
      0,
      (sum, payment) =>
          sum + (double.tryParse('${payment['payment_amount'] ?? 0}') ?? 0),
    );
    final schedule = <PaymentSchedule>[];
    final status = '${row['status'] ?? 'approved'}';

    // Only build an amortization schedule from terms saved with this loan.
    // Older loans without those fields remain visible, but are not fabricated.
    if (releasedDate != null && monthly != null && monthly > 0 && tenure > 0) {
      final paymentsByDate =
          payments
              .map((payment) {
                final date = DateTime.tryParse(
                  '${payment['payment_date'] ?? ''}',
                );
                return (
                  date: date,
                  amount:
                      double.tryParse('${payment['payment_amount'] ?? 0}') ??
                      0.0,
                );
              })
              .where((payment) => payment.date != null)
              .toList()
            ..sort((first, second) => first.date!.compareTo(second.date!));
      for (var index = 0; index < tenure; index++) {
        final dueDate = _addCalendarMonths(releasedDate, index + 1);
        final paidByDueDate = paymentsByDate
            .where((payment) => !payment.date!.isAfter(dueDate))
            .fold<double>(0, (sum, payment) => sum + payment.amount);
        final isCompleted =
            status == 'completed' ||
            paidByDueDate >= monthly * (index + 1) - 0.01;
        final hasNext = schedule.every(
          (payment) => payment.status == PaymentStatus.completed,
        );
        final paymentStatus = isCompleted
            ? PaymentStatus.completed
            : hasNext
            ? PaymentStatus.current
            : PaymentStatus.future;
        schedule.add(
          PaymentSchedule(
            month: index + 1,
            date: DateFormat('MMM d, yyyy').format(dueDate),
            amount: _formatCurrency(monthly),
            status: paymentStatus,
          ),
        );
      }
    }

    return Loan(
      id: '${row['application_id'] ?? row['id']}',
      loanType: '${row['loan_type'] ?? 'Loan'}'.toUpperCase(),
      principal: _formatCurrency(principal),
      disbursementDate: releasedDate == null
          ? 'Not recorded'
          : DateFormat('MMM d, yyyy').format(releasedDate),
      amortizationSchedule: schedule,
      status: status,
      actualAmountPaid: actualPaid,
    );
  }
}

DateTime _addCalendarMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day.clamp(1, lastDay));
}

double _parseCurrency(String amount) {
  return double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

String _formatCurrency(double amount) => '₱${amount.toStringAsFixed(2)}';

double _amountFor(Iterable<PaymentSchedule> payments) {
  return payments.fold(
    0,
    (sum, payment) => sum + _parseCurrency(payment.amount),
  );
}

class LoanDetailsScreen extends StatefulWidget {
  const LoanDetailsScreen({super.key});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<Loan> _loans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLoanDetails();
  }

  Future<void> _loadLoanDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await DatabaseService().getMemberLoanDetails();
      final loans = rows.map(Loan.fromDatabase).toList();
      if (!mounted) return;
      setState(() {
        _loans
          ..clear()
          ..addAll(loans);
        _currentPage = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'Unable to load your loan details. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null || _loans.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Loan Details')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadLoanDetails,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const Text('No approved or released loans were found.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const LoanDetailsAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _loans.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: LoanSummaryCard(
                              loan: _loans[index],
                              currentIndex: index,
                              totalLoans: _loans.length,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    LoanPageIndicator(
                      currentPage: _currentPage,
                      totalLoans: _loans.length,
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        key: ValueKey(_currentPage),
                        children: [
                          Expanded(
                            child: LoanInfoCard(
                              label: 'Monthly Payment',
                              amount: _loans[_currentPage].monthlyPayment,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingL),
                          Expanded(
                            child: LoanInfoCard(
                              label: 'Outstanding Balance',
                              amount:
                                  _loans[_currentPage]
                                      .amortizationSchedule
                                      .isEmpty
                                  ? 'Not recorded'
                                  : _formatCurrency(
                                      _loans[_currentPage].outstandingBalance,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: LoanProgressCard(
                        key: ValueKey('progress_$_currentPage'),
                        loan: _loans[_currentPage],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: AmortizationScheduleCard(
                        key: ValueKey('schedule_$_currentPage'),
                        payments: _loans[_currentPage].amortizationSchedule,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNavigationBar(currentIndex: 0, parentContext: context),
          ],
        ),
      ),
    );
  }
}

class LoanDetailsAppBar extends StatelessWidget {
  const LoanDetailsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingM,
      ),
      decoration: const BoxDecoration(color: AppTheme.cardWhite),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.backButtonBg,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.darkText,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          const Expanded(
            child: Text(
              'Loan Details',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoanSummaryCard extends StatelessWidget {
  final Loan loan;
  final int currentIndex;
  final int totalLoans;

  const LoanSummaryCard({
    super.key,
    required this.loan,
    required this.currentIndex,
    required this.totalLoans,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loan.loanType,
                style: const TextStyle(
                  color: AppTheme.lightGreenText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currentIndex + 1} of $totalLoans',
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    loan.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            loan.principal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Original Loan Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Disbursed ${loan.disbursementDate}',
            style: const TextStyle(
              color: AppTheme.lightGrayGreen,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          if (loan.amortizationSchedule.isEmpty)
            const Text(
              'Payment progress will appear when repayment terms are recorded.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: loan.paymentProgress,
                          backgroundColor: const Color(0xFF1A5A35),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentGold,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingL),
                Text(
                  '${(loan.paymentProgress * 100).round()}% paid',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class LoanInfoCard extends StatelessWidget {
  final String label;
  final String amount;

  const LoanInfoCard({super.key, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mutedGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            amount,
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class LoanProgressCard extends StatelessWidget {
  final Loan loan;

  const LoanProgressCard({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loan Progress',
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (loan.amortizationSchedule.isEmpty)
            const Text(
              'Repayment schedule details have not been recorded for this loan yet.',
              style: TextStyle(color: AppTheme.mutedGray),
            )
          else ...[
            _buildProgressRow(
              'Amount Paid',
              _formatCurrency(loan.amountPaid),
              emphasizeValue: true,
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildProgressRow(
              'Total Repayable',
              _formatCurrency(loan.totalRepayable),
              emphasizeValue: true,
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildProgressRow(
              'Outstanding Balance',
              '${_formatCurrency(loan.outstandingBalance)} Including interest',
              emphasizeValue: true,
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Text(
              'Payment Progress',
              style: TextStyle(
                color: AppTheme.mutedGray,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_formatCurrency(loan.amountPaid)} Paid / ${_formatCurrency(loan.totalRepayable)} Total',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: loan.paymentProgress.clamp(0.0, 1.0),
                backgroundColor: AppTheme.timelineGray,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryGreen,
                ),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildProgressRow(
              'Interest',
              '${_formatCurrency(loan.interestPaid)} paid / ${_formatCurrency(loan.totalInterest)} total',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildProgressRow(
              'Remaining Term',
              '${loan.remainingMonths} months left / ${loan.totalMonths} months',
              emphasizeValue: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    String label,
    String value, {
    bool emphasizeValue = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.mutedGray,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: emphasizeValue ? 16 : 14,
              fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AmortizationScheduleCard extends StatelessWidget {
  final List<PaymentSchedule> payments;

  const AmortizationScheduleCard({super.key, required this.payments});

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
            'AMORTIZATION SCHEDULE',
            style: TextStyle(
              color: AppTheme.mutedGray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          if (payments.isEmpty)
            const Text(
              'No repayment schedule has been recorded yet.',
              style: TextStyle(color: AppTheme.mutedGray),
            )
          else
            ...payments.asMap().entries.map((entry) {
              final index = entry.key;
              final payment = entry.value;
              final isLast = index == payments.length - 1;
              return Column(
                children: [
                  TimelineItem(payment: payment, showConnector: !isLast),
                  if (!isLast) const SizedBox(height: AppTheme.spacingS),
                ],
              );
            }),
        ],
      ),
    );
  }
}

enum PaymentStatus { completed, current, future }

class PaymentSchedule {
  final int month;
  final String date;
  final String amount;
  final PaymentStatus status;

  PaymentSchedule({
    required this.month,
    required this.date,
    required this.amount,
    required this.status,
  });
}

class TimelineItem extends StatelessWidget {
  final PaymentSchedule payment;
  final bool showConnector;

  const TimelineItem({
    super.key,
    required this.payment,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _buildIndicator(),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: payment.status == PaymentStatus.completed
                    ? AppTheme.timelineGray
                    : AppTheme.timelineGray,
              ),
          ],
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(child: _buildContent()),
        const SizedBox(width: AppTheme.spacingM),
        _buildAmount(),
      ],
    );
  }

  Widget _buildIndicator() {
    switch (payment.status) {
      case PaymentStatus.completed:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.completedGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        );
      case PaymentStatus.current:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentGold, width: 2),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      case PaymentStatus.future:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.timelineGray, width: 2),
          ),
        );
    }
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Month ${payment.month}',
          style: TextStyle(
            color: payment.status == PaymentStatus.completed
                ? AppTheme.mutedGray
                : AppTheme.primaryText,
            fontSize: 14,
            fontWeight: payment.status == PaymentStatus.current
                ? FontWeight.w700
                : FontWeight.w500,
            decoration: payment.status == PaymentStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          payment.date,
          style: TextStyle(
            color: payment.status == PaymentStatus.completed
                ? AppTheme.mutedGray
                : AppTheme.mutedGray,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            decoration: payment.status == PaymentStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAmount() {
    return Text(
      payment.amount,
      style: TextStyle(
        color: payment.status == PaymentStatus.completed
            ? AppTheme.mutedGray
            : AppTheme.primaryText,
        fontSize: 14,
        fontWeight: payment.status == PaymentStatus.current
            ? FontWeight.w700
            : FontWeight.w500,
        decoration: payment.status == PaymentStatus.completed
            ? TextDecoration.lineThrough
            : null,
      ),
    );
  }
}

class LoanPageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalLoans;

  const LoanPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalLoans,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalLoans,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentPage == index
                ? AppTheme.accentGold
                : AppTheme.timelineGray,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
