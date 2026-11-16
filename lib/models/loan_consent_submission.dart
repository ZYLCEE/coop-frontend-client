/// Values explicitly confirmed on the review screen, never inferred from submission.
class LoanConsentSubmission {
  const LoanConsentSubmission({
    required this.termsAccepted,
    required this.promissoryNoteAccepted,
    required this.promissoryNoteText,
    required this.informationCertified,
    this.witnessNames = const [],
  });

  static const termsVersion = 'csucc-loan-terms-2026-11-12-v1';
  static const promissoryNoteVersion = 'csucc-promissory-note-2026-11-14-v1';
  final bool termsAccepted;
  final bool promissoryNoteAccepted;
  final String promissoryNoteText;
  final bool informationCertified;
  final List<String> witnessNames;

  List<String> get normalizedWitnessNames => witnessNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);

  void validate() {
    if (!termsAccepted || !promissoryNoteAccepted || !informationCertified) {
      throw StateError(
        'Accept the Terms and Conditions and Promissory Note, then certify your application information.',
      );
    }
    if (promissoryNoteText.trim().length < 20 ||
        promissoryNoteText.length > 5000) {
      throw StateError('The Promissory Note details are invalid.');
    }
    final names = normalizedWitnessNames;
    if (names.length != 2) {
      throw StateError('Please enter both witness names before proceeding.');
    }
    if (names.any(
      (name) => name.length > 160 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(name),
    )) {
      throw StateError(
        'Enter two valid witness names, each at most 160 characters.',
      );
    }
    if (names.map((name) => name.toLowerCase()).toSet().length !=
        names.length) {
      throw StateError('Enter different people in the witness fields.');
    }
  }
}
