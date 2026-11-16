import 'dart:math';

enum LoanType {
  regular,
  educational,
  emergency,
  calamity,
  multiPurpose,
  quick,
  medical,
  livelihood,
  appliance,
  birthday,
  anniversary,
  fiesta,
  bonus,
  collateral,
  mortuary,
  subsistence,
  assme,
}

extension LoanTypeLabels on LoanType {
  String get label {
    switch (this) {
      case LoanType.regular:
        return 'Regular Loan';
      case LoanType.educational:
        return 'Educational Loan';
      case LoanType.emergency:
        return 'Emergency Loan';
      case LoanType.calamity:
        return 'Calamity Loan';
      case LoanType.multiPurpose:
        return 'Multi-Purpose Loan';
      case LoanType.quick:
        return 'Quick Loan';
      case LoanType.medical:
        return 'Medical Loan';
      case LoanType.livelihood:
        return 'Livelihood Loan';
      case LoanType.appliance:
        return 'Appliance Loan';
      case LoanType.birthday:
        return 'Birthday Loan';
      case LoanType.anniversary:
        return 'Anniversary Loan';
      case LoanType.fiesta:
        return 'Fiesta Loan';
      case LoanType.bonus:
        return 'Bonus Loan';
      case LoanType.collateral:
        return 'Collateral Loan';
      case LoanType.mortuary:
        return 'Mortuary Loan';
      case LoanType.subsistence:
        return 'Subsistence Loan';
      case LoanType.assme:
        return 'ASSME Loan';
    }
  }
}

class LoanTypeCatalog {
  static const List<LoanType> available = [
    LoanType.regular,
    LoanType.emergency,
    LoanType.multiPurpose,
    LoanType.quick,
    LoanType.educational,
    LoanType.medical,
    LoanType.livelihood,
    LoanType.appliance,
    LoanType.birthday,
    LoanType.anniversary,
    LoanType.fiesta,
    LoanType.bonus,
    LoanType.collateral,
    LoanType.mortuary,
    LoanType.subsistence,
    LoanType.assme,
  ];
}

class LoanEligibility {
  static Map<String, dynamic>? blockingApplication(
    LoanType type,
    Iterable<Map<String, dynamic>> loans,
  ) {
    final key = _typeKey(type.label);
    for (final loan in loans) {
      if (_typeKey('${loan['loan_type']}') != key) continue;
      switch (statusFor(loan)) {
        case 'pending':
        case 'under review':
        case 'approved':
        case 'released':
        case 'overdue':
          return loan;
      }
    }
    return null;
  }

  static String statusFor(Map<String, dynamic> loan) {
    final status = '${loan['status'] ?? 'unknown'}';
    if ((status == 'released' || status == 'overdue') && _isPaidOff(loan)) {
      return 'completed';
    }
    return status;
  }

  static bool _isPaidOff(Map<String, dynamic> loan) {
    final principal = double.tryParse('${loan['amount']}');
    final monthly = double.tryParse('${loan['monthly_payment']}');
    final months = int.tryParse('${loan['tenure_months']}');
    final rate = double.tryParse('${loan['interest_rate_at_release']}');
    if (principal == null ||
        principal <= 0 ||
        months == null ||
        months <= 0 ||
        ((monthly == null || monthly <= 0) && (rate == null || rate < 0))) {
      return false;
    }
    var principalPaid = 0.0;
    var interestPaid = 0.0;
    for (final payment in postedLoanPayments(loan)) {
      principalPaid += double.tryParse('${payment['principal_amount']}') ?? 0;
      interestPaid += double.tryParse('${payment['interest_amount']}') ?? 0;
    }
    final scheduledInterest = rate != null && rate >= 0
        ? LoanCalculatorService.diminishingSchedule(
            principal: principal,
            months: months,
            interestRatePercent: rate,
          ).fold<double>(0, (sum, period) => sum + period.interest)
        : ((monthly ?? 0) * months - principal).clamp(0.0, double.infinity);
    return (principalPaid * 100).round() >= (principal * 100).round() &&
        (interestPaid * 100).round() >= (scheduledInterest * 100).round();
  }

  static String _typeKey(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'\s+loan$'), '');
}

Iterable<Map<String, dynamic>> postedLoanPayments(Map<String, dynamic> loan) {
  final payments = loan['loan_payments'];
  if (payments is! List) return const [];
  return payments.whereType<Map<String, dynamic>>().where(
    (payment) =>
        payment['payment_status'] == null ||
        payment['payment_status'] == 'posted',
  );
}

class LoanAmortizationPeriod {
  final int number;
  final double openingBalance;
  final double interest;
  final double principal;
  final double payment;
  final double remainingPrincipal;

  const LoanAmortizationPeriod({
    required this.number,
    required this.openingBalance,
    required this.interest,
    required this.principal,
    required this.payment,
    required this.remainingPrincipal,
  });
}

class LoanComputation {
  final double principal;
  final double interestRate;
  final double totalInterest;
  final double totalRepayment;
  final double processingFee;
  final double notarialFee;
  final double retentionFee;
  final double loanInsurancePremium;
  final double loanInsuranceFactorPercent;
  final double serviceFeePercent;
  final double netTakeHome;
  final double monthlyAmortization;
  final List<DateTime> paymentDates;
  final List<LoanAmortizationPeriod> amortizationSchedule;

  LoanComputation({
    required this.principal,
    required this.interestRate,
    required this.totalInterest,
    required this.totalRepayment,
    required this.processingFee,
    required this.notarialFee,
    required this.retentionFee,
    required this.loanInsurancePremium,
    required this.loanInsuranceFactorPercent,
    required this.serviceFeePercent,
    required this.netTakeHome,
    required this.monthlyAmortization,
    required this.paymentDates,
    required this.amortizationSchedule,
  });
}

class LoanCalculatorService {
  static const double notarialFee = 150.0;
  static const double maxLoanAmount = 500000.0;
  static const double minLoanAmount = 1000.0;
  static const double goldLimit = 200000.0;

  static const Map<int, double> _lppiFactorsPercent = {
    1: 0.1629,
    2: 0.1629,
    3: 0.2444,
    4: 0.3259,
    5: 0.4073,
    6: 0.4888,
    7: 0.5703,
    8: 0.6518,
    9: 0.7332,
    10: 0.8147,
    11: 0.8962,
    12: 0.9750,
    13: 1.0519,
    14: 1.1406,
    15: 1.2221,
    16: 1.3036,
    17: 1.3850,
    18: 1.4665,
    19: 1.5430,
    20: 1.6295,
    21: 1.7110,
    22: 1.7924,
    23: 1.8739,
    24: 1.9500,
  };

  LoanComputation calculate({
    required double principal,
    required int months,
    required LoanType loanType,
    double baseInterestRatePercent = 1.5,
    double processingFeePercent = 1,
    double serviceFeePercent = 0.5,
  }) {
    if (!principal.isFinite ||
        principal <= 0 ||
        months <= 0 ||
        !baseInterestRatePercent.isFinite ||
        baseInterestRatePercent < 0) {
      throw ArgumentError(
        'Enter a positive principal, term, and valid interest rate.',
      );
    }

    int cents(double value) => (value * 100).round();
    double money(int value) => value / 100;
    final principalCents = cents(principal);
    final schedule = diminishingSchedule(
      principal: principal,
      months: months,
      interestRatePercent: baseInterestRatePercent,
    );
    final totalInterestCents = cents(
      schedule.fold<double>(0, (sum, period) => sum + period.interest),
    );
    final totalPaymentCents = cents(
      schedule.fold<double>(0, (sum, period) => sum + period.payment),
    );

    final processingFee = money(cents(principal * processingFeePercent / 100));
    final retentionFee = money(cents(principal * serviceFeePercent / 100));
    final insuranceFactor = lppiFactorPercent(months);
    final insurancePremium = money(cents(principal * insuranceFactor / 100));
    const notarialAmount = notarialFee;
    final netTakeHome = money(
      cents(principal) -
          cents(processingFee) -
          cents(notarialAmount) -
          cents(retentionFee) -
          cents(insurancePremium),
    );

    return LoanComputation(
      principal: money(principalCents),
      interestRate: baseInterestRatePercent,
      totalInterest: money(totalInterestCents),
      totalRepayment: money(totalPaymentCents),
      processingFee: processingFee,
      notarialFee: notarialAmount,
      retentionFee: retentionFee,
      loanInsurancePremium: insurancePremium,
      loanInsuranceFactorPercent: insuranceFactor,
      serviceFeePercent: serviceFeePercent,
      netTakeHome: netTakeHome,
      monthlyAmortization: schedule.first.payment,
      paymentDates: _generatePaymentDates(months),
      amortizationSchedule: List.unmodifiable(schedule),
    );
  }

  static double lppiFactorPercent(int months) {
    final factor = _lppiFactorsPercent[months];
    if (factor == null) {
      throw ArgumentError(
        'Loan insurance factors are available for terms 1–24 months.',
      );
    }
    return factor;
  }

  static List<LoanAmortizationPeriod> diminishingSchedule({
    required double principal,
    required int months,
    required double interestRatePercent,
  }) {
    if (!principal.isFinite ||
        principal <= 0 ||
        months <= 0 ||
        !interestRatePercent.isFinite ||
        interestRatePercent < 0) {
      throw ArgumentError('Enter valid principal, term, and interest rate.');
    }

    int cents(double value) => (value * 100).round();
    double money(int value) => value / 100;
    final principalCents = cents(principal);
    final regularPrincipalCents = (principalCents / months).round();
    var balanceCents = principalCents;
    final schedule = <LoanAmortizationPeriod>[];
    for (var index = 0; index < months; index++) {
      final openingBalanceCents = balanceCents;
      final principalPaidCents = index == months - 1
          ? openingBalanceCents
          : min(openingBalanceCents, regularPrincipalCents);
      final interestCents = (openingBalanceCents * interestRatePercent / 100)
          .round();
      final paymentCents = principalPaidCents + interestCents;
      balanceCents = max(openingBalanceCents - principalPaidCents, 0);
      schedule.add(
        LoanAmortizationPeriod(
          number: index + 1,
          openingBalance: money(openingBalanceCents),
          interest: money(interestCents),
          principal: money(principalPaidCents),
          payment: money(paymentCents),
          remainingPrincipal: money(balanceCents),
        ),
      );
    }
    return List.unmodifiable(schedule);
  }

  List<DateTime> _generatePaymentDates(int months) {
    List<DateTime> dates = [];
    DateTime startDate = DateTime.now();

    for (int i = 1; i <= months; i++) {
      DateTime paymentDate = DateTime(
        startDate.year,
        startDate.month + i,
        20, // Payment on the 20th of each month
      );
      dates.add(paymentDate);
    }

    return dates;
  }

  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  static String formatPercentage(double rate, {bool compact = false}) {
    final percentage = rate % 1 == 0
        ? rate.toStringAsFixed(0)
        : rate.toString();
    return compact
        ? '$percentage%/mo'
        : '$percentage% / month diminishing balance';
  }

  static String formatFeePercentage(double rate) {
    final percentage = rate % 1 == 0
        ? rate.toStringAsFixed(0)
        : rate.toString();
    return '$percentage%';
  }
}
