import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loan_application_mode.dart';
import 'loan_calculator_service.dart';
import 'models/loan_application_draft.dart';
import 'models/loan_agreement_snapshot.dart';
import 'models/loan_participant.dart';
import 'models/loan_submission_readiness.dart';
import 'services/loan_participant_lookup.dart';

/// In-memory inbox entry scoped to one fictional recipient and review.
class DemoCoMakerRequest {
  DemoCoMakerRequest._(
    this.revision,
    this.recipient,
    this.product,
    this.amount,
  );

  final int revision;
  final LoanCoMakerCandidate recipient;
  final String product;
  final double amount;
  bool _read = false;
  bool get isRead => _read;
  DemoCoMakerDecision _decision = DemoCoMakerDecision.pending;
  DemoCoMakerDecision get decision => _decision;
}

/// Owns the in-memory draft and routes for one application attempt.
class LoanApplicationFlow {
  LoanApplicationFlow(
    LoanType loanType,
    SupabaseClient client, {
    this.participantsDemo = loanParticipantsDemoBuild,
    this.previewOnly = false,
  }) : assert(!participantsDemo || !previewOnly),
       _client = client,
       _userId = client.auth.currentUser?.id,
       _draft = LoanApplicationDraft(loanType: loanType) {
    _subscription = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut ||
          (state.session != null && state.session!.user.id != _userId)) {
        close();
      }
    });
  }

  final bool participantsDemo;
  final bool previewOnly;
  bool get hasParticipantsStep => participantsDemo || previewOnly;
  final SupabaseClient _client;
  final String? _userId;
  LoanApplicationDraft? _draft;
  late final StreamSubscription<AuthState> _subscription;
  final _routes = <Route<void>>[];
  int _demoReviewRevision = 0;
  int? _activeDemoReview;
  LoanAgreementSnapshot? _activeDemoSnapshot;
  DemoCoMakerRequest? _demoRequest;
  final _declinedDemoCoMakers = <String>{};

  bool get canUseConsentDemo => participantsDemo && !previewOnly && isActive;
  bool get canUseLiveSubmission =>
      isActive &&
      !previewOnly &&
      !participantsDemo &&
      !loanParticipantsDemoBuild;

  int? beginConsentDemoReview(LoanAgreementSnapshot snapshot) {
    if (!canUseConsentDemo) return null;
    _demoRequest = null;
    _activeDemoSnapshot = snapshot;
    return _activeDemoReview = ++_demoReviewRevision;
  }

  void endConsentDemoReview(int revision) {
    if (_activeDemoReview != revision) return;
    _activeDemoReview = null;
    _activeDemoSnapshot = null;
    _demoRequest = null;
  }

  bool isCurrentDemoReview(int revision) {
    final snapshot = _activeDemoSnapshot;
    if (!canUseConsentDemo ||
        _activeDemoReview != revision ||
        snapshot == null) {
      return false;
    }
    final current = draft;
    if (snapshot.amount != current.amount ||
        snapshot.loanType != current.loanType ||
        snapshot.applicationKind != current.applicationKind ||
        snapshot.tenure != current.tenure ||
        !identical(snapshot.computation, current.computation) ||
        !listEquals(
          snapshot.repaymentDates,
          current.computation?.paymentDates,
        ) ||
        !identical(snapshot.policy, current.policy) ||
        snapshot.coMaker?.memberId != current.participants?.coMaker?.memberId) {
      endConsentDemoReview(revision);
      return false;
    }
    return true;
  }

  bool canRespondToDemoRequest(DemoCoMakerRequest request) =>
      demoRequestFor(request.revision, request.recipient.memberId) == request &&
      request.decision == DemoCoMakerDecision.pending;

  DemoCoMakerRequest? recordDemoBorrowerConfirmation(
    int revision,
    LoanAgreementSnapshot snapshot,
  ) {
    final selectedId = snapshot.coMaker?.memberId;
    if (!isCurrentDemoReview(revision) ||
        !identical(snapshot, _activeDemoSnapshot) ||
        selectedId == null ||
        hasDemoCoMakerDeclined(selectedId)) {
      return null;
    }
    final recipient = DemoLoanParticipantLookup.fictionalMember(selectedId);
    if (recipient == null) return null;
    return _demoRequest ??= DemoCoMakerRequest._(
      revision,
      recipient,
      snapshot.loanType.label,
      snapshot.amount,
    );
  }

  DemoCoMakerRequest? demoRequestFor(int revision, String recipientId) {
    if (!isCurrentDemoReview(revision)) return null;
    final request = _demoRequest;
    return request?.recipient.memberId == recipientId ? request : null;
  }

  bool markDemoRequestRead(DemoCoMakerRequest request) {
    if (demoRequestFor(request.revision, request.recipient.memberId) !=
        request) {
      return false;
    }
    request._read = true;
    return true;
  }

  bool resolveDemoRequest(
    DemoCoMakerRequest request,
    DemoCoMakerDecision decision,
  ) {
    if (!canRespondToDemoRequest(request) ||
        decision == DemoCoMakerDecision.pending) {
      return false;
    }
    request._decision = decision;
    request._read = true;
    if (decision == DemoCoMakerDecision.declined) {
      _declinedDemoCoMakers.add(request.recipient.memberId);
    }
    return true;
  }

  bool hasDemoCoMakerDeclined(String? memberId) =>
      canUseConsentDemo &&
      memberId != null &&
      _declinedDemoCoMakers.contains(
        DemoLoanParticipantLookup.fictionalMember(memberId)?.memberId,
      );

  bool get isActive =>
      _draft != null &&
      _userId != null &&
      _client.auth.currentUser?.id == _userId;

  LoanApplicationDraft get draft => _draft!;

  void attach(Route<void> route) => _routes.add(route);

  Future<void> push(
    BuildContext context,
    WidgetBuilder builder, {
    bool dialog = false,
  }) async {
    if (!isActive || ModalRoute.of(context)?.isCurrent != true) return;
    Widget buildPage(BuildContext context) =>
        isActive ? builder(context) : const SizedBox.shrink();
    final route = dialog
        ? DialogRoute<void>(context: context, builder: buildPage)
        : MaterialPageRoute<void>(builder: buildPage);
    attach(route);
    try {
      await Navigator.of(context).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void close({bool removeRoutes = true}) {
    if (_draft == null) return;
    _draft!.documents.clear();
    _draft!.applicant = null;
    _draft!.participants = null;
    _declinedDemoCoMakers.clear();
    _activeDemoReview = null;
    _activeDemoSnapshot = null;
    _demoRequest = null;
    _draft = null;
    unawaited(_subscription.cancel());
    final routes = _routes.reversed.toList();
    _routes.clear();
    if (removeRoutes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final route in routes) {
          if (route.isActive) route.navigator?.removeRoute(route);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }
}
