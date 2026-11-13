import 'loan_document.dart';

String normalizeParticipantMemberId(String input) =>
    input.trim().toUpperCase().replaceFirst(RegExp(r'^CSUCC-'), '');

class LoanCoMakerCandidate {
  const LoanCoMakerCandidate({
    required this.memberId,
    required this.name,
    this.isVerifiedMember = false,
    this.isDemo = false,
    this.eligibilityStatus = 'unknown',
  });

  final String memberId;
  final String name;
  final bool isVerifiedMember;
  final bool isDemo;
  final String eligibilityStatus;
}

/// In-memory selections for the participant prototype.
class LoanParticipantsDraft {
  String coMakerNameInput = '';
  LoanCoMakerCandidate? coMaker;
  String relationship = '';
  SelectedLoanDocument? coMakerIdDocument;
  String? coMakerIdDocumentPath;
  String witnessOne = '';
  String witnessTwo = '';
}
