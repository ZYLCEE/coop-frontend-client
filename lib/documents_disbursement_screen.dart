import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'application_summary_screen.dart';
import 'loan_calculator_service.dart';
import 'models/loan_document.dart';
import 'services/document_picker_service.dart';

class DocumentsDisbursementScreen extends StatefulWidget {
  final double loanAmount;
  final LoanType loanType;
  final int tenure;
  final LoanComputation computation;
  final double collateralRequiredAbove;
  final DocumentPickerService? picker;
  final ValueChanged<List<SelectedLoanDocument>>? onReview;

  const DocumentsDisbursementScreen({
    super.key,
    this.loanAmount = 50000.0,
    required this.loanType,
    required this.tenure,
    required this.computation,
    this.collateralRequiredAbove = 200000,
    this.picker,
    this.onReview,
  });

  @override
  State<DocumentsDisbursementScreen> createState() =>
      _DocumentsDisbursementScreenState();
}

class _DocumentsDisbursementScreenState
    extends State<DocumentsDisbursementScreen> {
  final _documents = <LoanDocumentKind, SelectedLoanDocument>{};
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
    _picker = widget.picker ?? DocumentPickerService();
    _recoverSelection();
  }

  Future<void> _recoverSelection() async {
    try {
      final recovered = await _picker.recoverLostSelection();
      if (mounted && recovered != null)
        setState(() => _documents[recovered.kind] = recovered);
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
      final source = await showModalBottomSheet<DocumentSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  kind.label,
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
                onTap: () => Navigator.pop(sheetContext, DocumentSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                subtitle: const Text('Choose an existing picture'),
                onTap: () =>
                    Navigator.pop(sheetContext, DocumentSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Files'),
                subtitle: const Text('Choose an image or PDF'),
                onTap: () => Navigator.pop(sheetContext, DocumentSource.files),
              ),
            ],
          ),
        ),
      );
      if (mounted) setState(() => _choosingSource = false);
      if (source == null || !mounted) return;
      final selected = await _picker.pick(kind, source);
      if (mounted && selected != null)
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

  bool get _isCollateralRequired =>
      widget.loanAmount > widget.collateralRequiredAbove;

  bool get _isValidated {
    if (_busy) return false;
    if (_payslipFileName == null || _idFileName == null) return false;
    if (_isCollateralRequired && _collateralFileName == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoanProgressIndicator(currentStep: 1),
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
              const SizedBox(height: AppTheme.spacingM),
              UploadRequirementCard(
                title: 'Collateral Document',
                subtitle: _isCollateralRequired
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
              const Text(
                'Images and PDFs, up to 10 MB each. Documents are saved when you submit the application.',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_busy && !_choosingSource)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              PrimaryButton(
                isEnabled: _isValidated,
                onPressed: _isValidated
                    ? () {
                        final documents =
                            List<SelectedLoanDocument>.unmodifiable(
                              _documents.values,
                            );
                        if (widget.onReview != null) {
                          widget.onReview!(documents);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApplicationSummaryScreen(
                              loanAmount: widget.loanAmount,
                              loanType: widget.loanType,
                              tenure: widget.tenure,
                              computation: widget.computation,
                              payslipFileName: _payslipFileName!,
                              idFileName: _idFileName!,
                              collateralFileName: _collateralFileName,
                              otherFileName: _otherFileName,
                              documents: documents,
                            ),
                          ),
                        );
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

class LoanProgressIndicator extends StatelessWidget {
  final int currentStep;

  const LoanProgressIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep('Loan Details', 0, currentStep),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 0
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
          ),
        ),
        _buildStep('Documents', 1, currentStep),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 1
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
          ),
        ),
        _buildStep('Review', 2, currentStep),
      ],
    );
  }

  Widget _buildStep(String label, int step, int currentStep) {
    final isActive = step == currentStep;
    final isCompleted = step < currentStep;

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class UploadRequirementCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? fileName;
  final bool isRequired;
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
                    : const Color(0xFFF3F5F4),
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
                    fileName ?? subtitle,
                    style: TextStyle(
                      color: fileName != null
                          ? AppTheme.primaryGreen
                          : const Color(0xFF7D8A82),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
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
