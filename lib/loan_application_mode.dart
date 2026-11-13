const loanParticipantsDemoBuild = bool.fromEnvironment(
  'LOAN_PARTICIPANTS_DEMO',
);

/// A frontend guard. The backend must independently authorize every live call.
void requireLiveLoanOperations({bool participantsDemo = false}) {
  if (loanParticipantsDemoBuild || participantsDemo) {
    throw StateError(
      'Live loan operations are disabled in the participant demo.',
    );
  }
}
