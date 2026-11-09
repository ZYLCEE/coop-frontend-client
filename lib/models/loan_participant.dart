String normalizeParticipantMemberId(String input) =>
    input.trim().toUpperCase().replaceFirst(RegExp(r'^CSUCC-'), '');

class LoanCoMakerCandidate {
  const LoanCoMakerCandidate({required this.memberId, required this.name});

  final String memberId;
  final String name;
}

/// In-memory selections for the participant prototype.
class LoanParticipantsDraft {
  String memberIdInput = '';
  LoanCoMakerCandidate? coMaker;
  String relationship = '';
  String witnessOne = '';
  String witnessTwo = '';
}
