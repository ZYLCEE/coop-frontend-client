import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'services/database_service.dart';

class MemberLoanPaymentHistoryScreen extends StatelessWidget {
  const MemberLoanPaymentHistoryScreen({
    super.key,
    required this.loanApplicationUuid,
    required this.applicationId,
    required this.totalRepayment,
    required this.monthlyInstallment,
    required this.loanCompleted,
    this.paymentStream,
  });

  final String loanApplicationUuid;
  final String applicationId;
  final double? totalRepayment;
  final double? monthlyInstallment;
  final bool loanCompleted;
  final Stream<List<Map<String, dynamic>>>? paymentStream;

  static final _currency = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );
  static final _date = DateFormat('MMM d, yyyy');

  static int _toCents(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    return amount == null || !amount.isFinite ? 0 : (amount * 100).round();
  }

  static String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? 'Date not recorded' : _date.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        title: const Text('Payment History', style: AppTheme.titleBold),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              paymentStream ??
              DatabaseService().watchMemberLoanPayments(loanApplicationUuid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load payment history. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final chronological =
                List<Map<String, dynamic>>.from(snapshot.data!)..sort((a, b) {
                  final dateOrder = (a['payment_date']?.toString() ?? '')
                      .compareTo(b['payment_date']?.toString() ?? '');
                  if (dateOrder != 0) return dateOrder;
                  final timeOrder = (a['created_at']?.toString() ?? '')
                      .compareTo(b['created_at']?.toString() ?? '');
                  if (timeOrder != 0) return timeOrder;
                  return (a['id']?.toString() ?? '').compareTo(
                    b['id']?.toString() ?? '',
                  );
                });

            if (chronological.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Text(
                    'No payments recorded for $applicationId.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            var cumulativePaidCents = 0;
            var lastPostedIndex = -1;
            for (var index = 0; index < chronological.length; index++) {
              final status =
                  (chronological[index]['payment_status'] ?? 'posted')
                      .toString();
              if (status == 'posted') lastPostedIndex = index;
            }
            final rows = <_HistoryRow>[];
            for (var index = 0; index < chronological.length; index++) {
              final payment = chronological[index];
              final status = (payment['payment_status'] ?? 'posted').toString();
              final posted = status == 'posted';
              final previousPaidCents = cumulativePaidCents;
              if (posted) {
                cumulativePaidCents += _toCents(payment['payment_amount']);
              }
              final totalCents = totalRepayment == null
                  ? null
                  : _toCents(totalRepayment);
              final installmentCents = monthlyInstallment == null
                  ? null
                  : _toCents(monthlyInstallment);
              final crossedInstallment =
                  installmentCents != null &&
                  installmentCents > 0 &&
                  cumulativePaidCents ~/ installmentCents >
                      previousPaidCents ~/ installmentCents;
              final remainingCents =
                  totalCents != null && cumulativePaidCents >= totalCents
                  ? 0
                  : installmentCents != null && installmentCents > 0
                  ? (cumulativePaidCents % installmentCents == 0
                        ? 0
                        : installmentCents -
                              cumulativePaidCents % installmentCents)
                  : totalCents == null
                  ? null
                  : max(totalCents - cumulativePaidCents, 0);
              final fullyPaid =
                  (totalCents != null && cumulativePaidCents >= totalCents) ||
                  (totalCents == null &&
                      loanCompleted &&
                      index == lastPostedIndex);
              rows.add(
                _HistoryRow(
                  payment: payment,
                  remainingBalance: remainingCents == null
                      ? null
                      : remainingCents / 100,
                  status: !posted
                      ? 'Reversed'
                      : fullyPaid || crossedInstallment
                      ? 'Paid'
                      : 'Partial Payment',
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              children: [
                Text(applicationId, style: AppTheme.bodyBold),
                const SizedBox(height: AppTheme.spacingM),
                for (final row in rows.reversed)
                  Card(
                    color: AppTheme.cardWhite,
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dateLabel(row.payment['payment_date']),
                                  style: AppTheme.bodyBold,
                                ),
                              ),
                              _StatusLabel(row.status),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          _detail(
                            'Amount paid',
                            _currency.format(
                              _toCents(row.payment['payment_amount']) / 100,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _detail(
                            'Remaining balance after payment',
                            row.remainingBalance == null
                                ? 'Not recorded'
                                : _currency.format(row.remainingBalance),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.mutedGray, fontSize: 13),
        ),
      ),
      const SizedBox(width: AppTheme.spacingS),
      Text(value, style: AppTheme.bodyBold),
    ],
  );
}

class _HistoryRow {
  const _HistoryRow({
    required this.payment,
    required this.remainingBalance,
    required this.status,
  });

  final Map<String, dynamic> payment;
  final double? remainingBalance;
  final String status;
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final reversed = status == 'Reversed';
    final color = reversed ? Colors.red.shade700 : AppTheme.primaryGreen;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
