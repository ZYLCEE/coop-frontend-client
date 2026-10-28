import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan_document.dart';

class LoanDocumentUploadService {
  LoanDocumentUploadService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  static const bucket = 'loan-documents';

  Future<void> submit({
    required String applicationId,
    required String loanType,
    required double amount,
    required List<SelectedLoanDocument> documents,
    required int tenureMonths,
    void Function(String)? onProgress,
  }) async {
    validateLoanDocuments(documents, amount);
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before submitting documents.');
    final type = loanType.replaceFirst(RegExp(r'\s+Loan$'), '');
    final policy = await _client
        .from('loan_policy_settings')
        .select('collateral_required_above')
        .eq('singleton', true)
        .single();
    final collateralRequiredAbove = double.parse(
      '${policy['collateral_required_above']}',
    );
    final member = await _client
        .from('members')
        .select('id, status, must_change_password')
        .eq('user_id', user.id)
        .single();
    if (member['status'] != 'active' ||
        member['must_change_password'] == true) {
      throw StateError(
        'Sign in with an active member account and complete password setup before submitting.',
      );
    }
    final existing = await _client
        .from('loan_applications')
        .select('id, member_id, amount, loan_type, tenure_months')
        .eq('application_id', applicationId)
        .maybeSingle();
    if (existing != null) {
      final saved = await _client
          .from('loan_documents')
          .select('kind')
          .eq('loan_application_id', existing['id']);
      final kinds = saved.map((row) => row['kind']).toSet();
      if (existing['member_id'] == member['id'] &&
          existing['loan_type'] == type &&
          double.tryParse('${existing['amount']}') == amount &&
          existing['tenure_months'] == tenureMonths &&
          kinds.contains('payslip') &&
          kinds.contains('validId') &&
          (amount <= collateralRequiredAbove || kinds.contains('collateral'))) {
        return; // A previous submission committed but its response was lost.
      }
      throw StateError(
        'This reference has already been used. Please start a new application.',
      );
    }
    final nonce = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final paths = <String>[];
    final metadata = <Map<String, dynamic>>[];
    try {
      for (final document in documents) {
        if (_client.auth.currentUser?.id != user.id)
          throw StateError('Your session changed. Please sign in again.');
        final path =
            '${user.id}/$applicationId/${document.kind.name}_$nonce.${document.extension}';
        onProgress?.call('Uploading ${document.kind.label}...');
        await _client.storage
            .from(bucket)
            .uploadBinary(
              path,
              document.bytes,
              fileOptions: FileOptions(
                contentType: document.contentType,
                upsert: false,
              ),
            );
        paths.add(path);
        metadata.add({
          'kind': document.kind.name,
          'path': path,
          'name': document.name,
          'mimeType': document.contentType,
          'size': document.bytes.length,
        });
      }
      if (_client.auth.currentUser?.id != user.id)
        throw StateError('Your session changed. Please sign in again.');
      onProgress?.call('Saving application and documents...');
      await _client.rpc(
        'submit_loan_with_documents',
        params: {
          'p_application_id': applicationId,
          'p_loan_type': type,
          'p_amount': amount,
          'p_documents': metadata,
          'p_tenure_months': tenureMonths,
        },
      );
    } catch (failure) {
      // Storage RLS refuses removal of files referenced by committed documents.
      // This also protects successful submissions whose response was lost.
      if (paths.isNotEmpty) {
        try {
          await _client.storage.from(bucket).remove(paths);
        } catch (_) {
          /* Retry can reconcile a committed submission. */
        }
      }
      if (failure is StateError) rethrow;
      if (failure is PostgrestException && failure.code == 'P0001')
        throw StateError(failure.message);
      throw StateError(
        'Unable to upload your documents and submit the application. Check your connection and retry.',
      );
    }
  }
}
