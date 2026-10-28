import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/schedtracker.dart';

void main() {
  test(
    'Loan details are built from saved application, terms, and payment rows',
    () {
      final loan = Loan.fromDatabase({
        'application_id': 'LA-2026-123456',
        'loan_type': 'Regular',
        'amount': '12000.00',
        'status': 'released',
        'date_released': '2099-01-31',
        'tenure_months': 3,
        'monthly_payment': '440.00',
        'loan_payments': [
          {'payment_amount': '440.00', 'payment_date': '2099-02-28'},
        ],
      });

      expect(loan.id, 'LA-2026-123456');
      expect(loan.status, 'released');
      expect(loan.principal, '₱12000.00');
      expect(loan.monthlyPayment, '₱440.00');
      expect(loan.amortizationSchedule, hasLength(3));
      expect(loan.amortizationSchedule.first.status, PaymentStatus.completed);
      expect(loan.amountPaid, 440);
      expect(loan.remainingMonths, 2);
    },
  );

  test(
    'Does not fabricate a repayment schedule when saved loan terms are absent',
    () {
      final loan = Loan.fromDatabase({
        'application_id': 'LA-2026-123456',
        'loan_type': 'Regular',
        'amount': '12000.00',
        'status': 'approved',
        'date_approved': '2026-10-01',
        'loan_payments': [],
      });
      expect(loan.status, 'approved');
      expect(loan.amortizationSchedule, isEmpty);
      expect(loan.disbursementDate, 'Not recorded');
    },
  );
}
