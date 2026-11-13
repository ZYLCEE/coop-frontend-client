import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'documents_disbursement_screen.dart';
import 'loan_application_flow.dart';
import 'models/loan_document.dart';
import 'models/loan_participant.dart';
import 'responsive.dart';
import 'services/document_picker_service.dart';
import 'services/loan_participant_lookup.dart';
import 'widgets/loan_progress_indicator.dart';

class LoanParticipantsScreen extends StatefulWidget {
  const LoanParticipantsScreen({super.key, required this.flow, this.lookup});

  final LoanApplicationFlow flow;
  final LoanParticipantLookup? lookup;

  @override
  State<LoanParticipantsScreen> createState() => _LoanParticipantsScreenState();
}

class _LoanParticipantsScreenState extends State<LoanParticipantsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _pickingCoMakerDocument = false;
  String? _lookupError;
  String? _documentError;
  late final DocumentPickerService _documentPicker = DocumentPickerService();

  LoanParticipantsDraft get _participants =>
      widget.flow.draft.participants ??= LoanParticipantsDraft();

  LoanParticipantLookup get _lookup =>
      widget.lookup ??
      (widget.flow.participantsDemo
          ? const DemoLoanParticipantLookup()
          : SupabaseLoanParticipantLookup(
              client: Supabase.instance.client,
              supabaseUrl: dotenv.env['SUPABASE_URL'] ?? '',
              allowedProjectRef: 'jhgsqvxlvwhrwpcekvpq',
            ));

  Future<void> _findCoMaker() async {
    if (_loading ||
        !widget.flow.isActive ||
        (!widget.flow.previewOnly &&
            !widget.flow.canUseConsentDemo &&
            !widget.flow.canUseLiveSubmission)) {
      return;
    }
    final participants = _participants;
    final name = participants.coMakerNameInput.trim().replaceAll(RegExp(r'\s+'), ' ');
    final borrowerId = normalizeParticipantMemberId(
      widget.flow.draft.applicant?['member_id']?.toString() ?? '',
    );
    if (name.split(' ').length < 2) {
      setState(() {
        _lookupError = 'Enter the co-maker’s first and last name.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _lookupError = null;
    });
    LoanCoMakerCandidate? candidate;
    String? error;
    try {
      candidate = await _lookup.findByName(name);
      if (candidate == null) {
        error = !widget.flow.participantsDemo
            ? 'No active member was found with that name.'
            : 'Demo member not found. Check the name and try again.';
      } else if (normalizeParticipantMemberId(candidate.memberId) ==
          borrowerId) {
        candidate = null;
        error = 'Choose a co-maker other than yourself.';
      } else if (!widget.flow.participantsDemo && !candidate.isVerifiedMember) {
        candidate = null;
        error = 'The member service did not verify an active member.';
      } else if (widget.flow.participantsDemo && !candidate.isDemo) {
        candidate = null;
        error = 'The demo lookup did not return a demo member.';
      }
    } catch (exception) {
      error = exception is LoanParticipantLookupException
          ? exception.message
          : !widget.flow.participantsDemo
          ? 'Member verification failed. Confirm the lookup service is deployed and try again.'
          : 'Demo member lookup is unavailable. Try again.';
    }
    if (!mounted ||
        !widget.flow.isActive ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      _loading = false;
      _lookupError = error;
      if (participants.coMaker?.memberId != candidate?.memberId) {
        participants.coMakerIdDocument = null;
        participants.coMakerIdDocumentPath = null;
      }
      participants.coMaker = candidate;
    });
  }

  Future<void> _pickCoMakerIdDocument() async {
    if (_pickingCoMakerDocument ||
        _participants.coMaker == null ||
        !widget.flow.canUseLiveSubmission) {
      return;
    }
    setState(() {
      _pickingCoMakerDocument = true;
      _documentError = null;
    });
    try {
      final document = await _documentPicker.pick(
        LoanDocumentKind.supporting,
        DocumentSource.files,
      );
      if (!mounted || !widget.flow.isActive) return;
      if (document != null) {
        setState(() {
          _participants
            ..coMakerIdDocument = document
            ..coMakerIdDocumentPath = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _documentError = _documentMessage(error));
    } finally {
      if (mounted) setState(() => _pickingCoMakerDocument = false);
    }
  }

  void _continue() {
    if (_loading || !widget.flow.isActive) return;
    final selected = _participants.coMaker;
    final selectedIsValid =
        selected != null &&
        (widget.flow.participantsDemo
            ? selected.isDemo
            : selected.isVerifiedMember);
    if (!selectedIsValid) {
      setState(() {
        _lookupError = !widget.flow.participantsDemo
            ? 'A verified member lookup is required before continuing.'
            : 'Look up and select a demo co-maker.';
      });
      return;
    }
    final valid = _formKey.currentState!.validate();
    if (!valid) return;
    if (widget.flow.canUseLiveSubmission &&
        _participants.coMakerIdDocument == null) {
      setState(() => _documentError = 'Attach the co-maker ID document.');
      return;
    }
    widget.flow.push(
      context,
      (_) => DocumentsDisbursementScreen.forFlow(widget.flow),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.flow.isActive || !widget.flow.hasParticipantsStep) {
      return const Scaffold(
        body: Center(child: Text('Participant selection demo')),
      );
    }
    final participants = _participants;
    final candidate = participants.coMaker;
    final borrowerId = normalizeParticipantMemberId(
      widget.flow.draft.applicant?['member_id']?.toString() ?? '',
    );
    final firstWitness = participants.witnessOne.trim().toLowerCase();
    final secondWitness = participants.witnessTwo.trim().toLowerCase();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.mutedGray,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Participants', style: AppTheme.titleBold),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoanProgressIndicator.forApplication(
                  LoanApplicationStep.participants,
                  participantsDemo: widget.flow.participantsDemo,
                  previewOnly: widget.flow.previewOnly,
                  hasParticipants: widget.flow.hasParticipantsStep,
                ),
                const SizedBox(height: AppTheme.spacingL),
                const Text(
                  'Co-Maker and Witness Information',
                  style: AppTheme.headingBold,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  widget.flow.previewOnly
                      ? 'Review the participant steps in this local draft.'
                      : widget.flow.participantsDemo
                      ? 'Identify one co-maker and up to two witnesses for this practice draft. Use fictional witness names.'
                      : 'Verify an active co-maker member. They must be different from you and must accept the invitation before the loan is submitted.',
                  style: AppTheme.bodyRegular,
                ),
                const SizedBox(height: AppTheme.spacingL),
                _card('Co-Maker', [
                  _field(
                    'Co-Maker Member Name',
                    participants.coMakerNameInput,
                    (value) => setState(() {
                      participants.coMakerNameInput = value;
                      final selected = participants.coMaker;
                      if (selected != null && value.trim().toLowerCase() != selected.name.trim().toLowerCase()) {
                        participants.coMaker = null;
                        participants.relationship = '';
                        participants.coMakerIdDocument = null;
                        participants.coMakerIdDocumentPath = null;
                        _documentError = null;
                      }
                      _lookupError = null;
                    }),
                    enabled: !_loading,
                    error: _lookupError,
                    validator: (value) {
                      final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
                      if (name.isEmpty) return 'Enter the co-maker’s name.';
                      if (name.split(' ').length < 2) return 'Enter the co-maker’s first and last name.';
                      if (candidate == null ||
                          candidate.name.trim().toLowerCase() != name.toLowerCase() ||
                          (!widget.flow.participantsDemo &&
                              !candidate.isVerifiedMember) ||
                          (widget.flow.participantsDemo && !candidate.isDemo)) {
                        return 'Look up this name and select a registered member.';
                      }
                      return null;
                    },
                  ),
                  TextButton(
                    onPressed: _loading ? null : _findCoMaker,
                    child: Text(
                      _loading
                          ? !widget.flow.participantsDemo
                                ? 'Searching member name…'
                                : 'Looking up demo member…'
                          : !widget.flow.participantsDemo
                          ? 'Verify Co-maker Member Name'
                          : 'Look Up Demo Member',
                    ),
                  ),
                  if (widget.flow.participantsDemo)
                    const Text(
                      'Example demo names: Demo Member One and Demo Member Two.',
                      style: AppTheme.captionRegular,
                    ),
                  if (candidate != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Text(candidate.name, style: AppTheme.bodyBold),
                    Text(
                      !widget.flow.participantsDemo
                          ? 'Active member account verified. Co-maker eligibility rules are still pending.'
                          : 'Fictional demo record. This is not a real member verification.',
                      style: AppTheme.captionRegular,
                    ),
                  ],
                  if (!widget.flow.participantsDemo &&
                      !widget.flow.previewOnly) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Co-maker ID Document',
                        errorText: _documentError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              participants.coMakerIdDocument?.name ??
                                  'PDF or image, up to 10 MB',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodyRegular,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                _pickingCoMakerDocument ||
                                    candidate?.isVerifiedMember != true ||
                                    !widget.flow.canUseLiveSubmission
                                ? null
                                : _pickCoMakerIdDocument,
                            child: Text(
                              _pickingCoMakerDocument
                                  ? 'Selecting…'
                                  : participants.coMakerIdDocument == null
                                  ? 'Add Document'
                                  : 'Replace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      candidate?.isVerifiedMember == true
                          ? 'Attach a clear PDF or image of the co-maker ID, up to 10 MB.'
                          : 'Verify an active co-maker before adding their ID document.',
                      style: AppTheme.captionRegular,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingM),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: participants.relationship.isEmpty
                        ? null
                        : participants.relationship,
                    decoration: InputDecoration(
                      labelText: 'Relationship to borrower',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    items:
                        const [
                          'Spouse',
                          'Parent',
                          'Child',
                          'Sibling',
                          'Other relative',
                          'Friend',
                          'Colleague',
                          'Co-worker',
                          'Other',
                        ].map((relationship) {
                          return DropdownMenuItem(
                            value: relationship,
                            child: Text(relationship),
                          );
                        }).toList(),
                    onChanged: (relationship) => setState(() {
                      participants.relationship = relationship ?? '';
                    }),
                    validator: (relationship) => (relationship ?? '').isEmpty
                        ? 'Select the relationship to the borrower.'
                        : null,
                  ),
                ]),
                const SizedBox(height: AppTheme.spacingL),
                _card('Witnesses', [
                  const Text(
                    'These slots are provisional. Witness eligibility and attestation procedures are pending cooperative confirmation.',
                    style: AppTheme.captionRegular,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  _field(
                    'Witness 1',
                    participants.witnessOne,
                    (value) => setState(() => participants.witnessOne = value),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  _field(
                    'Witness 2',
                    participants.witnessTwo,
                    (value) => setState(() => participants.witnessTwo = value),
                  ),
                  if (firstWitness.isNotEmpty && firstWitness == secondWitness)
                    const Padding(
                      padding: EdgeInsets.only(top: AppTheme.spacingS),
                      child: Text(
                        'Both witness slots have the same name. Check whether you entered the same person twice.',
                        style: AppTheme.captionBold,
                      ),
                    ),
                ]),
                const SizedBox(height: AppTheme.spacingL),
                _card('Participant Summary', [
                  Text(
                    candidate == null
                        ? 'Co-Maker: Not Verified'
                        : widget.flow.participantsDemo
                        ? 'Co-Maker: Selected for demo'
                        : 'Co-Maker: ${candidate.name} (${candidate.memberId})',
                  ),
                  Text(
                    firstWitness.isEmpty
                        ? 'Witness 1: Not Identified'
                        : 'Witness 1: Identified',
                  ),
                  Text(
                    secondWitness.isEmpty
                        ? 'Witness 2: Not Identified'
                        : 'Witness 2: Identified',
                  ),
                ]),
                const SizedBox(height: AppTheme.spacingXL),
                SizedBox(
                  height: Responsive.buttonHeight(context),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.lightGrayGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.buttonBorderRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue to Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(AppTheme.spacingL),
    decoration: BoxDecoration(
      color: AppTheme.cardWhite,
      borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.titleBold),
        const SizedBox(height: AppTheme.spacingM),
        ...children,
      ],
    ),
  );

  Widget _field(
    String label,
    String initialValue,
    ValueChanged<String> onChanged, {
    Key? key,
    bool enabled = true,
    String? error,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    key: key,
    initialValue: initialValue,
    enabled: enabled,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      errorMaxLines: 3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryGreen),
      ),
    ),
  );

  String _documentMessage(Object error) {
    if (error is StateError) return error.message.toString();
    return 'Unable to select the co-maker ID document. Try again.';
  }
}
