class LoanPolicySettings {
  const LoanPolicySettings({
    required this.baseInterestRatePercent,
    required this.processingFeePercent,
    required this.serviceFeePercent,
    required this.minMemberTenureMonths,
    required this.minLoanAmount,
    required this.maxLoanAmount,
    required this.maxLoanMultiplier,
    required this.penaltyRatePercent,
    required this.coMakerRequiredAbove,
    required this.collateralRequiredAbove,
    required this.loanProcessingTime,
  });

  final double baseInterestRatePercent;
  final double processingFeePercent;
  final double serviceFeePercent;
  final int minMemberTenureMonths;
  final double minLoanAmount;
  final double maxLoanAmount;
  final double maxLoanMultiplier;
  final double penaltyRatePercent;
  final double coMakerRequiredAbove;
  final double collateralRequiredAbove;
  final String loanProcessingTime;

  factory LoanPolicySettings.fromMap(Map<String, dynamic> row) =>
      LoanPolicySettings(
        baseInterestRatePercent: _number(row['base_interest_rate']),
        processingFeePercent: _number(row['processing_fee_percent']),
        serviceFeePercent: _number(row['service_fee_percent']),
        minMemberTenureMonths: _number(row['min_member_tenure_months']).round(),
        minLoanAmount: _number(row['min_loan_amount']),
        maxLoanAmount: _number(row['max_loan_amount']),
        maxLoanMultiplier: _number(row['max_loan_multiplier']),
        penaltyRatePercent: _number(row['penalty_rate_percent']),
        coMakerRequiredAbove: _number(row['co_maker_required_above']),
        collateralRequiredAbove: _number(row['collateral_required_above']),
        loanProcessingTime: row['loan_processing_time'] is String
            ? row['loan_processing_time'] as String
            : 'Not specified',
      );

  static double _number(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    final parsed = double.tryParse('$value');
    if (parsed == null || !parsed.isFinite)
      throw const FormatException('Invalid loan policy value.');
    return parsed;
  }
}
