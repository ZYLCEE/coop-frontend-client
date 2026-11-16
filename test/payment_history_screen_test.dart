import 'dart:async';
import 'package:coop_frontend/payment_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps partial receipts separate and tracks remaining installment',
    (tester) async {
      final controller =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberLoanPaymentHistoryScreen(
            loanApplicationUuid: 'loan-uuid',
            applicationId: 'LA-2026-0001',
            totalRepayment: 31000,
            monthlyInstallment: 5166.67,
            loanCompleted: false,
            paymentStream: controller.stream,
          ),
        ),
      );
      controller.add([
        {
          'id': 'p1',
          'payment_date': '2026-01-01',
          'created_at': '2026-01-01T08:00:00Z',
          'payment_amount': 2500,
          'payment_status': 'posted',
        },
      ]);
      await tester.pump();
      expect(find.text('₱2,500.00'), findsOneWidget);
      expect(find.text('₱2,666.67'), findsOneWidget);
      expect(find.text('Partial Payment'), findsOneWidget);
      controller.add([
        {
          'id': 'p1',
          'payment_date': '2026-01-01',
          'created_at': '2026-01-01T08:00:00Z',
          'payment_amount': 2500,
          'payment_status': 'posted',
        },
        {
          'id': 'p2',
          'payment_date': '2026-01-02',
          'created_at': '2026-01-02T08:00:00Z',
          'payment_amount': 2666.67,
          'payment_status': 'posted',
        },
      ]);
      await tester.pump();
      expect(find.text('₱2,500.00'), findsOneWidget);
      expect(find.text('₱2,666.67'), findsNWidgets(2));
      expect(find.text('₱0.00'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    },
  );

  testWidgets(
    'marks a full installment payment paid with zero remaining balance',
    (tester) async {
      final controller =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberLoanPaymentHistoryScreen(
            loanApplicationUuid: 'loan-uuid',
            applicationId: 'LA-2026-0001',
            totalRepayment: 5166.67,
            monthlyInstallment: 5166.67,
            loanCompleted: false,
            paymentStream: controller.stream,
          ),
        ),
      );
      controller.add([
        {
          'id': 'full',
          'payment_date': '2026-01-20',
          'created_at': '2026-01-20T08:00:00Z',
          'payment_amount': 5166.67,
          'payment_status': 'posted',
        },
      ]);
      await tester.pump();
      expect(find.text('₱5,166.67'), findsOneWidget);
      expect(find.text('₱0.00'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    },
  );
}
