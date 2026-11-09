import '../models/loan_participant.dart';

abstract interface class LoanParticipantLookup {
  Future<LoanCoMakerCandidate?> findByMemberId(String normalizedId);
}

/// Local fixtures. A match identifies a demo record, not a real member.
class DemoLoanParticipantLookup implements LoanParticipantLookup {
  const DemoLoanParticipantLookup();

  static const exampleMemberId = 'CSUCC-2099-9001';
  static const _candidates = {
    '2099-9001': LoanCoMakerCandidate(
      memberId: exampleMemberId,
      name: 'Demo Member One',
    ),
    '2099-9002': LoanCoMakerCandidate(
      memberId: 'CSUCC-2099-9002',
      name: 'Demo Member Two',
    ),
  };

  static LoanCoMakerCandidate? fictionalMember(String memberId) =>
      _candidates[normalizeParticipantMemberId(memberId)];

  @override
  Future<LoanCoMakerCandidate?> findByMemberId(String normalizedId) async =>
      fictionalMember(normalizedId);
}
