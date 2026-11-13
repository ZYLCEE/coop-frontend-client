import 'loan_application_flow.dart';
import 'widgets/loan_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'application_summary_screen.dart';
import 'loan_calculator_service.dart';
import 'models/loan_document.dart';
import 'services/document_picker_service.dart';

class DocumentsDisbursementScreen extends StatefulWidget {
  final LoanApplicationFlow? flow;
  final double loanAmount;
  final LoanType loanType;
  final int tenure;
  final LoanComputation computation;
  final double collateralRequiredAbove;
  final DocumentPickerService? picker;
  final ValueChanged<List<SelectedLoanDocument>>? onReview;

  const DocumentsDisbursementScreen({
    super.key,
    this.flow,
    this.loanAmount = 50000.0,
    required this.loanType,
    required this.tenure,
    required this.computation,
    this.collateralRequiredAbove = 200000,
    this.picker,
    this.onReview,
  });

  factory DocumentsDisbursementScreen.forFlow(LoanApplicationFlow flow) {
    final draft = flow.draft;
    return DocumentsDisbursementScreen(
      flow: flow,
      loanAmount: draft.amount,
      loanType: draft.loanType,
      tenure: draft.tenure,
      computation: draft.computation!,
      collateralRequiredAbove: draft.policy!.collateralRequiredAbove,
    );
  }

  @override
  State<DocumentsDisbursementScreen> createState() =>
      _DocumentsDisbursementScreenState();
}

class _DocumentsDisbursementScreenState
    extends State<DocumentsDisbursementScreen> {
  late final _documents =
      widget.flow?.draft.documents ??
      <LoanDocumentKind, SelectedLoanDocument>{};
  bool get _active => mounted && (widget.flow?.isActive ?? true);
  late final DocumentPickerService _picker;
  bool _busy = true;
  bool _choosingSource = false;
  String? _error;
  String? get _payslipFileName => _documents[LoanDocumentKind.payslip]?.name;
  String? get _idFileName => _documents[LoanDocumentKind.validId]?.name;
  String? get _collateralFileName =>
      _documents[LoanDocumentKind.collateral]?.name;
  String? get _otherFileName => _documents[LoanDocumentKind.supporting]?.name;

  @override
  void initState() {
    super.initState();
    _picker =
        widget.picker ??
        DocumentPickerService(
          recoverInterruptedImages: widget.flow?.previewOnly != true,
        );
    _recoverSelection();
  }

  Future<void> _recoverSelection() async {
    try {
      final recovered = await _picker.recoverLostSelection();
      if (_active && recovered != null && _isVisible(recovered.kind))
        setState(() => _documents.putIfAbsent(recovered.kind, () => recovered));
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Unable to recover the previous image selection. Please choose it again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDocument(LoanDocumentKind kind) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _choosingSource = true;
      _error = null;
    });
    try {
      final source = await showDialog<DocumentSource>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      kind.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Camera'),
                    subtitle: const Text('Take a photo'),
                    onTap: () =>
                        Navigator.pop(dialogContext, DocumentSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Gallery'),
                    subtitle: const Text('Choose an existing picture'),
                    onTap: () =>
                        Navigator.pop(dialogContext, DocumentSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('Files'),
                    subtitle: const Text('Choose an image or PDF'),
                    onTap: () =>
                        Navigator.pop(dialogContext, DocumentSource.files),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted) setState(() => _choosingSource = false);
      if (source == null || !_active) return;
      final selected = await _picker.pick(kind, source);
      if (_active && selected != null && _isVisible(kind))
        setState(() => _documents[kind] = selected);
    } catch (failure) {
      if (mounted)
        setState(
          () => _error =
              '${kind.label}: ${failure is StateError ? failure.message : 'Unable to select this file. Please try again.'}',
        );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _choosingSource = false;
        });
    }
  }

  bool get _participantsDemo => widget.flow?.participantsDemo ?? false;
  double get _amount {
    final flow = widget.flow;
    return flow != null && flow.isActive
        ? flow.draft.amount
        : widget.loanAmount;
  }

  bool _isVisible(LoanDocumentKind kind) =>
      kind.isVisibleFor(amount: _amount, participantsDemo: _participantsDemo);

  bool _isRequired(LoanDocumentKind kind) => kind.isRequiredFor(
    amount: _amount,
    participantsDemo: _participantsDemo,
    collateralRequiredAbove: widget.collateralRequiredAbove,
  );

  bool get _isCollateralRequired => _isRequired(LoanDocumentKind.collateral);

  @override
  Widget build(BuildContext context) {
    final showCollateral = _isVisible(LoanDocumentKind.collateral);
    final missing = LoanDocumentKind.values.where(
      (kind) => _isRequired(kind) && !_documents.containsKey(kind),
    );
    final previewOnly = widget.flow?.previewOnly ?? false;
    final canReview = !_busy && (previewOnly || missing.isEmpty);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LoanProgressIndicator.forApplication(
                LoanApplicationStep.documents,
                participantsDemo: _participantsDemo,
                previewOnly: previewOnly,
                hasParticipants: widget.flow?.hasParticipantsStep ?? false,
              ),
              const SizedBox(height: AppTheme.spacingL),
              const Text(
                'UPLOAD REQUIREMENTS',
                style: TextStyle(
                  color: Color(0xFF7D8A82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              UploadRequirementCard(
                title: 'Pay Slip *',
                subtitle: 'Latest payslip (within 3 months)',
                fileName: _payslipFileName,
                document: _documents[LoanDocumentKind.payslip],
                enabled: !_busy,
                onUpload: () => _pickDocument(LoanDocumentKind.payslip),
                onRemove: () =>
                    setState(() => _documents.remove(LoanDocumentKind.payslip)),
              ),
              const SizedBox(height: AppTheme.spacingM),
              UploadRequirementCard(
                title: 'Valid Identification *',
                subtitle: 'Government-issued photo ID',
                fileName: _idFileName,
                document: _documents[LoanDocumentKind.validId],
                enabled: !_busy,
                onUpload: () => _pickDocument(LoanDocumentKind.validId),
                onRemove: () =>
                    setState(() => _documents.remove(LoanDocumentKind.validId)),
              ),
              if (showCollateral) ...[
                const SizedBox(height: AppTheme.spacingM),
                UploadRequirementCard(
                  title: 'Collateral Document',
                  requirementLabel: _participantsDemo
                      ? 'Required in demo'
                      : null,
                  subtitle: _participantsDemo
                      ? 'Required in this demo at ₱200,000 and above. Proposed rule pending CSUCC confirmation.'
                      : _isCollateralRequired
                      ? 'Required for loans over ${LoanCalculatorService.formatCurrency(widget.collateralRequiredAbove)}'
                      : 'Optional (required for loans over ${LoanCalculatorService.formatCurrency(widget.collateralRequiredAbove)})',
                  fileName: _collateralFileName,
                  isRequired: _isCollateralRequired,
                  document: _documents[LoanDocumentKind.collateral],
                  enabled: !_busy,
                  onUpload: () => _pickDocument(LoanDocumentKind.collateral),
                  onRemove: () => setState(
                    () => _documents.remove(LoanDocumentKind.collateral),
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingM),
              UploadRequirementCard(
                title: 'Other Supporting Documents',
                subtitle: 'Optional additional documents',
                fileName: _otherFileName,
                isRequired: false,
                document: _documents[LoanDocumentKind.supporting],
                enabled: !_busy,
                onUpload: () => _pickDocument(LoanDocumentKind.supporting),
                onRemove: () => setState(
                  () => _documents.remove(LoanDocumentKind.supporting),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              Text(
                previewOnly
                    ? 'Images and PDFs, up to 10 MB each. Files stay in this local preview.'
                    : _participantsDemo
                    ? 'Images and PDFs, up to 10 MB each. Use sample files for this local demo.'
                    : 'Images and PDFs, up to 10 MB each. Documents are uploaded at submission.',
                style: AppTheme.captionRegular,
              ),
              if (!showCollateral && _collateralFileName != null)
                const Padding(
                  padding: EdgeInsets.only(top: AppTheme.spacingM),
                  child: Text(
                    'Your collateral file is kept in this draft and excluded '
                    'from review at this amount. It becomes available again '
                    'at ₱200,000 or above.',
                    style: AppTheme.captionRegular,
                  ),
                ),
              if (!_busy && missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingM,
                  ),
                  child: Text(
                    '${previewOnly ? 'Missing in this draft' : 'Required before review'}: ${missing.map((kind) => kind.label).join(', ')}.',
                    style: AppTheme.captionBold,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ),
              if (_busy && !_choosingSource)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              PrimaryButton(
                isEnabled: canReview,
                onPressed: canReview
                    ? () {
                        if (widget.onReview != null) {
                          widget.onReview!(
                            List<SelectedLoanDocument>.unmodifiable(
                              _documents.values.where(
                                (file) => _isVisible(file.kind),
                              ),
                            ),
                          );
                          return;
                        }
                        final flow = widget.flow;
                        if (flow != null) {
                          flow.push(
                            context,
                            (_) => ApplicationSummaryScreen(flow: flow),
                          );
                        }
                      }
                    : null,
              ),
              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      title: const Text(
        'Documents & Disbursement',
        style: TextStyle(
          color: Color(0xFF183A24),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }
}

class UploadRequirementCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? fileName;
  final bool isRequired;
  final String? requirementLabel;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;
  final SelectedLoanDocument? document;
  final bool enabled;

  const UploadRequirementCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.fileName,
    this.isRequired = true,
    this.requirementLabel,
    required this.onUpload,
    this.onRemove,
    this.document,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onUpload : null,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: fileName != null
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: document?.isImage == true
                  ? Image.memory(
                      document!.bytes,
                      cacheWidth: 128,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_outlined,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : Icon(
                      fileName != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      color: fileName != null
                          ? AppTheme.primaryGreen
                          : const Color(0xFF7D8A82),
                      size: 24,
                    ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF183A24),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    requirementLabel ?? (isRequired ? 'Required' : 'Optional'),
                    style: AppTheme.captionBold,
                  ),
                  Text(
                    fileName ?? subtitle,
                    style: TextStyle(
                      color: fileName != null
                          ? AppTheme.primaryGreen
                          : const Color(0xFF7D8A82),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (fileName != null)
                    const Text(
                      'Tap card to replace',
                      style: AppTheme.captionRegular,
                    ),
                ],
              ),
            ),
            if (document?.isImage == true)
              IconButton(
                tooltip: 'Preview document',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: !enabled
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(fileName ?? title),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                              ),
                              Flexible(
                                child: InteractiveViewer(
                                  child: Image.memory(
                                    document!.bytes,
                                    cacheWidth: 1600,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'Preview is unavailable for this image format. You can still attach the original file.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            if (document != null)
              IconButton(
                tooltip: 'Remove document',
                icon: const Icon(Icons.close),
                onPressed: enabled ? onRemove : null,
              ),
            if (document == null)
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF7D8A82),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.isEnabled, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppTheme.primaryGreen
              : const Color(0xFFB8C4B8),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Continue to Review',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
