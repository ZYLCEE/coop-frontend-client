import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../loan_calculator_service.dart';
import '../models/loan_agreement_snapshot.dart';
import '../models/loan_document.dart';
import '../models/loan_participant.dart';

class CoMakerInvitationService {
  CoMakerInvitationService({
    SupabaseClient? client,
    required this.supabaseUrl,
    this.allowedProjectRef = 'jhgsqvxlvwhrwpcekvpq',
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String supabaseUrl;
  final String allowedProjectRef;

  void _ensureMainProject() {
    final projectRef = Uri.tryParse(supabaseUrl)?.host.split('.').first;
    if (projectRef != allowedProjectRef) {
      throw StateError(
        'Co-maker invitations are restricted to the configured project.',
      );
    }
    if (_client.auth.currentSession == null) {
      throw StateError('Sign in with an active member account to continue.');
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String applicationId,
    required LoanCoMakerCandidate coMaker,
    required String relationship,
    required String coMakerIdDocumentPath,
    required LoanAgreementSnapshot snapshot,
  }) async {
    _ensureMainProject();
    return _invoke({
      'action': 'create',
      'application_id': applicationId,
      'co_maker_member_id': coMaker.memberId,
      'co_maker_id_document_path': coMakerIdDocumentPath,
      'relationship': relationship,
      'loan_type': snapshot.loanType.label,
      'amount': snapshot.amount,
      'tenure_months': snapshot.tenure,
      'loan_details': {
        'monthly_amortization': LoanCalculatorService.formatCurrency(
          snapshot.computation.monthlyAmortization,
        ),
        'interest_rate': LoanCalculatorService.formatPercentage(
          snapshot.computation.interestRate,
        ),
        'total_interest': LoanCalculatorService.formatCurrency(
          snapshot.computation.totalInterest,
        ),
        'processing_fee': LoanCalculatorService.formatCurrency(
          snapshot.computation.processingFee,
        ),
        'notarial_fee': LoanCalculatorService.formatCurrency(
          snapshot.computation.notarialFee,
        ),
        'retention_fee': LoanCalculatorService.formatCurrency(
          snapshot.computation.retentionFee,
        ),
        'net_take_home': LoanCalculatorService.formatCurrency(
          snapshot.computation.netTakeHome,
        ),
      },
    });
  }

  Future<String> uploadCoMakerIdDocument({
    required String applicationId,
    required SelectedLoanDocument document,
  }) async {
    _ensureMainProject();
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before uploading documents.');
    if (document.bytes.length > SelectedLoanDocument.maxBytes) {
      throw StateError('Choose a file no larger than 10 MB.');
    }
    final nonce = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final path =
        '${user.id}/$applicationId/co_maker_id_$nonce.${document.extension}';
    await _client.storage
        .from('loan-documents')
        .uploadBinary(
          path,
          document.bytes,
          fileOptions: FileOptions(
            contentType: document.contentType,
            upsert: false,
          ),
        );
    if (_client.auth.currentUser?.id != user.id) {
      try {
        await _client.storage.from('loan-documents').remove([path]);
      } catch (_) {}
      throw StateError('Your session changed. Please sign in again.');
    }
    return path;
  }

  Future<void> removeCoMakerIdDocument(String path) async {
    _ensureMainProject();
    final userId = _client.auth.currentUser?.id;
    if (userId == null || !path.startsWith('$userId/')) return;
    await _client.storage.from('loan-documents').remove([path]);
  }

  Future<Map<String, dynamic>> getRequest(String requestId) async {
    _ensureMainProject();
    final data = await _client
        .from('co_maker_requests')
        .select(
          'id, application_id, borrower_user_id, co_maker_user_id, borrower_name, co_maker_name, '
          'relationship, loan_type, amount, tenure_months, loan_details, status, created_at',
        )
        .eq('id', requestId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> beginAccept(String requestId) =>
      _action(action: 'begin_accept', requestId: requestId);

  Future<Map<String, dynamic>> reject(String requestId) =>
      _action(action: 'reject', requestId: requestId);

  Future<Map<String, dynamic>> confirmAccept(String requestId) =>
      _action(action: 'confirm_accept', requestId: requestId);

  Future<Map<String, dynamic>> _action({
    required String action,
    required String requestId,
  }) async {
    _ensureMainProject();
    return _invoke({'action': action, 'request_id': requestId});
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'co-maker-invitation',
        body: body,
      );
      return _readResponse(response.data);
    } on FunctionException catch (exception) {
      final details = exception.details;
      final message = details is Map ? details['error'] : null;
      if (message is String && message.isNotEmpty) throw StateError(message);
      if (exception.status == 404) {
        throw StateError('The co-maker invitation function is not deployed.');
      }
      throw StateError(
        'Co-maker invitation service is unavailable. Try again.',
      );
    }
  }

  Future<void> sendAcceptanceOtp(String email) async {
    _ensureMainProject();
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<void> verifyAcceptanceOtp({
    required String email,
    required String token,
  }) async {
    _ensureMainProject();
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Map<String, dynamic> _readResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['error'] is String) throw StateError(data['error'] as String);
      return data;
    }
    if (data is Map) {
      final response = Map<String, dynamic>.from(data);
      if (response['error'] is String) {
        throw StateError(response['error'] as String);
      }
      return response;
    }
    throw StateError(
      'Co-maker invitation service returned an invalid response.',
    );
  }
}
