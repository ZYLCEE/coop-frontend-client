import 'package:supabase_flutter/supabase_flutter.dart';

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
      isDemo: true,
    ),
    '2099-9002': LoanCoMakerCandidate(
      memberId: 'CSUCC-2099-9002',
      name: 'Demo Member Two',
      isDemo: true,
    ),
  };

  static LoanCoMakerCandidate? fictionalMember(String memberId) =>
      _candidates[normalizeParticipantMemberId(memberId)];

  @override
  Future<LoanCoMakerCandidate?> findByMemberId(String normalizedId) async =>
      fictionalMember(normalizedId);
}

/// Calls the authenticated lookup function only on the designated staging
/// project. It fails closed when the app is configured for another project.
class SupabaseLoanParticipantLookup implements LoanParticipantLookup {
  const SupabaseLoanParticipantLookup({
    required SupabaseClient client,
    required this.supabaseUrl,
    required this.allowedProjectRef,
  }) : _client = client;

  final SupabaseClient _client;
  final String supabaseUrl;
  final String allowedProjectRef;

  @override
  Future<LoanCoMakerCandidate?> findByMemberId(String normalizedId) async {
    final projectRef = Uri.tryParse(supabaseUrl)?.host.split('.').first;
    if (projectRef != allowedProjectRef) {
      throw const LoanParticipantLookupException(
        'Member lookup is restricted to the configured Supabase project.',
      );
    }
    if (_client.auth.currentSession == null) {
      throw const LoanParticipantLookupException(
        'Sign in with an active member account to verify the co-maker.',
      );
    }

    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'co-maker-lookup',
        body: {'member_id': normalizedId},
      );
    } on FunctionException catch (exception) {
      final details = exception.details;
      final message = details is Map ? details['error'] : null;
      if (message is String && message.isNotEmpty) {
        throw LoanParticipantLookupException(message);
      }
      if (exception.status == 404) {
        throw const LoanParticipantLookupException(
          'No active member was found for that Member ID.',
        );
      }
      throw const LoanParticipantLookupException(
        'Member lookup is unavailable. Confirm the staging function is deployed.',
      );
    }
    if (response.status != 200 || response.data is! Map) {
      throw const LoanParticipantLookupException(
        'Member lookup is unavailable. Confirm the staging function is deployed.',
      );
    }

    final payload = Map<String, dynamic>.from(response.data as Map);
    final candidate = payload['candidate'];
    if (candidate is! Map ||
        payload['eligibilityStatus'] != 'pending_policy' ||
        payload['submissionAllowed'] != false) {
      throw const LoanParticipantLookupException(
        'The staging lookup returned an unexpected response.',
      );
    }

    final candidateData = Map<String, dynamic>.from(candidate);
    final memberId = candidateData['memberId'];
    final name = candidateData['name'];
    if (memberId is! String || name is! String) {
      throw const LoanParticipantLookupException(
        'The staging lookup returned incomplete member information.',
      );
    }

    return LoanCoMakerCandidate(
      memberId: memberId,
      name: name,
      isVerifiedMember: true,
      eligibilityStatus: 'pending_policy',
    );
  }
}

class LoanParticipantLookupException implements Exception {
  const LoanParticipantLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}
