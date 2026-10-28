import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coop_frontend/documents_disbursement_screen.dart';
import 'package:coop_frontend/models/loan_document.dart';
import 'package:coop_frontend/services/document_picker_service.dart';
import 'package:coop_frontend/loan_calculator_service.dart';

class FakeDocumentPicker extends DocumentPickerService {
  final selections = <(LoanDocumentKind, DocumentSource)>[];
  bool cancel = false;
  @override
  Future<SelectedLoanDocument?> recoverLostSelection() async => null;
  @override
  Future<SelectedLoanDocument?> pick(
    LoanDocumentKind kind,
    DocumentSource source,
  ) async {
    selections.add((kind, source));
    if (cancel) return null;
    return SelectedLoanDocument.fromBytes(
      kind: kind,
      name: '${kind.name}.pdf',
      bytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
    );
  }
}

void main() {
  Future<void> openDocuments(
    WidgetTester tester,
    FakeDocumentPicker picker, {
    double amount = 50000,
    ValueChanged<List<SelectedLoanDocument>>? onReview,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentsDisbursementScreen(
          loanAmount: amount,
          loanType: LoanType.regular,
          tenure: 12,
          computation: LoanCalculatorService().calculate(
            principal: amount,
            months: 12,
            loanType: LoanType.regular,
          ),
          picker: picker,
          onReview: onReview,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String title, String source) async {
    await tester.ensureVisible(find.text(title));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    await tester.tap(find.text(source));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Each requirement offers all sources and review retains the selected data',
    (tester) async {
      final picker = FakeDocumentPicker();
      List<SelectedLoanDocument>? reviewed;
      await openDocuments(
        tester,
        picker,
        onReview: (documents) => reviewed = documents,
      );
      await select(tester, 'Pay Slip *', 'Camera');
      await select(tester, 'Valid Identification *', 'Gallery');
      await select(tester, 'Collateral Document', 'Files');
      await select(tester, 'Other Supporting Documents', 'Files');
      expect(picker.selections, [
        (LoanDocumentKind.payslip, DocumentSource.camera),
        (LoanDocumentKind.validId, DocumentSource.gallery),
        (LoanDocumentKind.collateral, DocumentSource.files),
        (LoanDocumentKind.supporting, DocumentSource.files),
      ]);
      await tester.ensureVisible(find.text('Continue to Review'));
      await tester.tap(find.text('Continue to Review'));
      await tester.pumpAndSettle();
      expect(reviewed, hasLength(4));
      expect(reviewed!.first.bytes, isNotEmpty);
    },
  );
  testWidgets(
    'Required attachments control review; cancellation preserves the old selection',
    (tester) async {
      final picker = FakeDocumentPicker();
      await openDocuments(tester, picker, amount: 250000);
      bool reviewEnabled() =>
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Continue to Review'),
              )
              .onPressed !=
          null;
      expect(reviewEnabled(), isFalse);
      await select(tester, 'Pay Slip *', 'Files');
      picker.cancel = true;
      await select(tester, 'Pay Slip *', 'Camera');
      expect(find.text('payslip.pdf'), findsOneWidget);
      picker.cancel = false;
      await select(tester, 'Valid Identification *', 'Files');
      expect(reviewEnabled(), isFalse);
      await select(tester, 'Collateral Document', 'Files');
      expect(reviewEnabled(), isTrue);
      await tester.ensureVisible(find.byTooltip('Remove document').first);
      await tester.tap(find.byTooltip('Remove document').first);
      await tester.pumpAndSettle();
      expect(reviewEnabled(), isFalse);
    },
  );
}
