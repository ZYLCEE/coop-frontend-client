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
  static const Set<LoanType> ongoingLoanTypes = {};

  static bool isOngoing(LoanType loanType) {
    return ongoingLoanTypes.contains(loanType);
  }

  static LoanType get defaultType {
    return LoanTypeCatalog.available.firstWhere(
      (loanType) => !isOngoing(loanType),
    );
  }
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
      interestRate: interestRate * 100, // Convert to percentage
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

  static String formatPercentage(double rate) {
    return '${rate.toStringAsFixed(0)}% / month flat';
  }
}
