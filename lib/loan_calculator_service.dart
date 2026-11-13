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
    if (principal == null ||
        principal <= 0 ||
        monthly == null ||
        monthly <= 0 ||
        months == null ||
        months <= 0) {
      return false;
    }
    var principalPaid = 0.0;
    var interestPaid = 0.0;
    for (final payment in postedLoanPayments(loan)) {
      principalPaid += double.tryParse('${payment['principal_amount']}') ?? 0;
      interestPaid += double.tryParse('${payment['interest_amount']}') ?? 0;
    }
    return (principalPaid * 100).round() >= (principal * 100).round() &&
        (interestPaid * 100).round() >=
            ((monthly * months - principal) * 100).round();
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

class LoanComputation {
  final double principal;
  final double interestRate;
  final double totalInterest;
  final double processingFee;
  final double notarialFee;
  final double retentionFee;
  final double netTakeHome;
  final double monthlyAmortization;
  final List<DateTime> paymentDates;

  LoanComputation({
    required this.principal,
    required this.interestRate,
    required this.totalInterest,
    required this.processingFee,
    required this.notarialFee,
    required this.retentionFee,
    required this.netTakeHome,
    required this.monthlyAmortization,
    required this.paymentDates,
  });
}

class LoanCalculatorService {
  static const double notarialFee = 150.0;
  static const double maxLoanAmount = 500000.0;
  static const double minLoanAmount = 1000.0;
  static const double goldLimit = 200000.0;

  LoanComputation calculate({
    required double principal,
    required int months,
    required LoanType loanType,
    double baseInterestRatePercent = 1.5,
    double processingFeePercent = 1,
    double serviceFeePercent = 0.5,
  }) {
    final interestRate = baseInterestRatePercent / 100;

    // Calculate total interest
    double totalInterest = principal * interestRate * months;

    // Calculate fees
    final processingFee = principal * processingFeePercent / 100;
    final retentionFee = principal * serviceFeePercent / 100;

    // Calculate net take-home
    double netTakeHome =
        principal - totalInterest - processingFee - notarialFee - retentionFee;

    // Calculate monthly amortization
    double monthlyAmortization =
        principal / months + (principal * interestRate);

    // Generate payment dates
    List<DateTime> paymentDates = _generatePaymentDates(months);

    return LoanComputation(
      principal: principal,
      interestRate: baseInterestRatePercent,
      totalInterest: totalInterest,
      processingFee: processingFee,
      notarialFee: notarialFee,
      retentionFee: retentionFee,
      netTakeHome: netTakeHome,
      monthlyAmortization: monthlyAmortization,
      paymentDates: paymentDates,
    );
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
    return compact ? '$percentage%/mo' : '$percentage% / month flat';
  }
}
