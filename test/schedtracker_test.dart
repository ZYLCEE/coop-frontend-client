import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/loan_calculator_service.dart';
import 'package:coop_frontend/schedtracker.dart';

void main() {
  test(
    'A newer application leaves earlier terms and posted payments intact',
    () {
      final earlier = Loan.fromDatabase({
        'application_id': 'LA-2026-000001',
        'loan_type': 'Regular',
        'amount': 12000,
        'status': 'released',
        'date_released': '2026-01-31',
        'monthly_payment': 4400,
        'tenure_months': 3,
        'loan_payments': [
          {
            'payment_amount': 4500,
            'principal_amount': 4000,
            'interest_amount': 400,
            'payment_status': 'posted',
            'payment_date': '2026-03-02',
          },
          {'payment_amount': 4400, 'payment_status': 'reversed'},
        ],
      });
      final newer = Loan.fromDatabase({
        'application_id': 'LA-2026-000002',
        'loan_type': 'Emergency',
        'amount': 5000,
        'status': 'pending',
        'monthly_payment': 550,
      });

      expect(newer.id, isNot(earlier.id));
      expect(newer.principalAmount, 5000);
      expect(newer.monthlyPayment, '₱550.00');
      expect(newer.amountPaid, 0);
      expect(earlier.principalAmount, 12000);
      expect(earlier.amountPaid, 4400);
      expect(earlier.outstandingBalance, 8800);
      expect(
        earlier.amortizationSchedule.first.status,
        PaymentStatus.completed,
      );
    },
  );

  test(
    'Only the same loan type stays blocked until its payments are posted',
    () {
      final loan = <String, dynamic>{
        'loan_type': ' regular loan ',
        'status': 'overdue',
        'amount': 1000,
        'monthly_payment': 550,
        'tenure_months': 2,
        'loan_payments': [
          {
            'principal_amount': 1000,
            'interest_amount': 50,
            'payment_status': 'posted',
          },
          {
            'principal_amount': 0,
            'interest_amount': 50,
            'payment_status': 'reversed',
          },
        ],
      };

      expect(
        LoanEligibility.blockingApplication(LoanType.regular, [loan]),
        same(loan),
      );
      expect(
        LoanEligibility.blockingApplication(LoanType.emergency, [loan]),
        isNull,
      );

      loan['loan_payments'] = [
        {
          'principal_amount': 1000,
          'interest_amount': 100,
          'payment_status': 'posted',
        },
      ];
      expect(
        LoanEligibility.blockingApplication(LoanType.regular, [loan]),
        isNull,
      );

      loan['status'] = 'pending';
      expect(
        LoanEligibility.blockingApplication(LoanType.regular, [loan]),
        same(loan),
      );
    },
  );

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
