import '../loan_calculator_service.dart';
import 'loan_document.dart';
import 'loan_participant.dart';
import 'loan_policy.dart';

enum LoanApplicationKind {
  newLoan('New'),
  renewal('Renewal');

  const LoanApplicationKind(this.label);
  final String label;
}

class LoanApplicationDraft {
  LoanApplicationDraft({
    required this.loanType,
    this.requireCoMaker = false,
  });

  Map<String, dynamic>? applicant;
  bool profileConfirmed = false;
  LoanType loanType;
  bool requireCoMaker;
  // The current submission service has no field for this paper-form choice.
  LoanApplicationKind? applicationKind;
  double amount = 50000;
  int tenure = 12;
  LoanPolicySettings? policy;
  LoanComputation? computation;
  LoanParticipantsDraft? participants;
  String? applicationId;
  String? coMakerRequestId;
  final documents = <LoanDocumentKind, SelectedLoanDocument>{};
}
