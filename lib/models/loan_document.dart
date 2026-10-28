import 'dart:typed_data';

enum LoanDocumentKind { payslip, validId, collateral, supporting }

enum DocumentSource { camera, gallery, files }

extension LoanDocumentLabels on LoanDocumentKind {
  String get label => switch (this) {
    LoanDocumentKind.payslip => 'Pay Slip',
    LoanDocumentKind.validId => 'Valid Identification',
    LoanDocumentKind.collateral => 'Collateral Document',
    LoanDocumentKind.supporting => 'Other Supporting Documents',
  };
}

class SelectedLoanDocument {
  SelectedLoanDocument._(
    this.kind,
    this.name,
    this.bytes,
    this.contentType,
    this.extension,
  );
  static const maxBytes = 10 * 1024 * 1024;
  static const supportedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'pdf',
  ];

  final LoanDocumentKind kind;
  final String name;
  final Uint8List bytes;
  final String contentType;
  final String extension;
  bool get isImage => contentType.startsWith('image/');

  factory SelectedLoanDocument.fromBytes({
    required LoanDocumentKind kind,
    required String name,
    required Uint8List bytes,
  }) {
    final cleanName = name.split(RegExp(r'[/\\]')).last.trim();
    if (cleanName.isEmpty || cleanName.length > 255)
      throw StateError(
        'The selected filename is invalid. Rename the file and try again.',
      );
    if (bytes.isEmpty)
      throw StateError(
        'The selected file is empty. Please select another file.',
      );
    if (bytes.length > maxBytes)
      throw StateError('Choose a file no larger than 10 MB.');
    final ext = cleanName.split('.').last.toLowerCase();
    final prefix = String.fromCharCodes(bytes.take(16));
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final isPng =
        bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
    final isWebp =
        prefix.startsWith('RIFF') &&
        prefix.length >= 12 &&
        prefix.substring(8, 12) == 'WEBP';
    final isHeif =
        prefix.length >= 12 &&
        prefix.substring(4, 8) == 'ftyp' &&
        [
          'heic',
          'heix',
          'hevc',
          'hevx',
          'heim',
          'heis',
          'mif1',
          'msf1',
        ].contains(prefix.substring(8, 12));
    final type = switch (ext) {
      'jpg' || 'jpeg' when isJpeg => 'image/jpeg',
      'png' when isPng => 'image/png',
      'webp' when isWebp => 'image/webp',
      'heic' when isHeif => 'image/heic',
      'heif' when isHeif => 'image/heif',
      'pdf' when prefix.startsWith('%PDF-') => 'application/pdf',
      _ => null,
    };
    if (type == null)
      throw StateError(
        'Choose a valid JPG, PNG, WEBP, HEIC/HEIF image or PDF document.',
      );
    return SelectedLoanDocument._(
      kind,
      cleanName,
      bytes,
      type,
      ext == 'jpeg' ? 'jpg' : ext,
    );
  }
}

void validateLoanDocuments(
  List<SelectedLoanDocument> documents,
  double amount,
) {
  final kinds = documents.map((document) => document.kind).toSet();
  if (kinds.length != documents.length)
    throw StateError('Attach only one file for each document requirement.');
  if (!kinds.contains(LoanDocumentKind.payslip))
    throw StateError('Please attach your latest payslip.');
  if (!kinds.contains(LoanDocumentKind.validId))
    throw StateError('Please attach a valid identification document.');
  if (amount > 200000 && !kinds.contains(LoanDocumentKind.collateral)) {
    throw StateError(
      'A collateral document is required for loans over ₱200,000.',
    );
  }
}
