import '../loan_calculator_service.dart';
import 'loan_application_draft.dart';
import 'loan_document.dart';
import 'loan_participant.dart';
import 'loan_policy.dart';

typedef LoanPreviewAttachment = ({
  String name,
  String extension,
  int sizeBytes,
});

/// Captured when review opens. Backend agreement identity and signatures belong
/// to a later, server-issued version.
class LoanAgreementSnapshot {
  LoanAgreementSnapshot.fromDraft(
    LoanApplicationDraft draft, {
    this.participantsDemo = false,
  }) : applicant = Map.unmodifiable(draft.applicant ?? const {}),
       loanType = draft.loanType,
       applicationKind = draft.applicationKind,
       amount = draft.amount,
       tenure = draft.tenure,
       computation = draft.computation!,
       repaymentDates = List.unmodifiable(draft.computation!.paymentDates),
       policy = draft.policy!,
       profileConfirmed = draft.profileConfirmed,
       coMaker = draft.participants?.coMaker,
       coMakerIdDocumentName = draft.participants?.coMakerIdDocument?.name,
       relationship = draft.participants?.relationship.trim() ?? '',
       witnessOne = draft.participants?.witnessOne.trim() ?? '',
       witnessTwo = draft.participants?.witnessTwo.trim() ?? '',
       documents = Map.unmodifiable({
         for (final entry in draft.documents.entries)
           if (entry.key.isVisibleFor(
             amount: draft.amount,
             participantsDemo: participantsDemo,
           ))
             entry.key: (
               name: entry.value.name,
               extension: entry.value.extension,
               sizeBytes: entry.value.bytes.length,
             ),
       });

  final Map<String, dynamic> applicant;
  final LoanType loanType;
  final LoanApplicationKind? applicationKind;
  final double amount;
  final bool participantsDemo;
  final int tenure;
  final LoanComputation computation;
  final List<DateTime> repaymentDates;
  final LoanPolicySettings policy;
  final bool profileConfirmed;

  double get collateralRequiredAbove => policy.collateralRequiredAbove;
  final LoanCoMakerCandidate? coMaker;
  final String? coMakerIdDocumentName;
  final String relationship;
  final String witnessOne;
  final String witnessTwo;
  final Map<LoanDocumentKind, LoanPreviewAttachment> documents;

  Iterable<LoanDocumentKind> get visibleDocumentKinds =>
      LoanDocumentKind.values.where(
        (kind) => kind.isVisibleFor(
          amount: amount,
          participantsDemo: participantsDemo,
        ),
      );

  bool requiresDocument(LoanDocumentKind kind) => kind.isRequiredFor(
    amount: amount,
    collateralRequiredAbove: collateralRequiredAbove,
    participantsDemo: participantsDemo,
  );
}
