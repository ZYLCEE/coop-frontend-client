import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:coop_frontend/models/loan_document.dart';
import 'package:coop_frontend/services/document_picker_service.dart';
import 'support/quick_access_fakes.dart';

Uint8List pdfBytes() =>
    Uint8List.fromList(utf8.encode('%PDF-1.4\nDocument test\n%%EOF'));
SelectedLoanDocument document(LoanDocumentKind kind) =>
    SelectedLoanDocument.fromBytes(
      kind: kind,
      name: '${kind.name}.pdf',
      bytes: pdfBytes(),
    );

void main() {
  test('Supported document retains its actual bytes and content type', () {
    final selected = document(LoanDocumentKind.payslip);
    expect(selected.bytes, pdfBytes());
    expect(selected.contentType, 'application/pdf');
    expect(selected.isImage, isFalse);
  });
  test(
    'Rejects empty files, oversized files, and extension/content mismatches',
    () {
      expect(
        () => SelectedLoanDocument.fromBytes(
          kind: LoanDocumentKind.validId,
          name: 'id.jpg',
          bytes: Uint8List(0),
        ),
        throwsStateError,
      );
      expect(
        () => SelectedLoanDocument.fromBytes(
          kind: LoanDocumentKind.validId,
          name: 'id.jpg',
          bytes: pdfBytes(),
        ),
        throwsStateError,
      );
      expect(
        () => SelectedLoanDocument.fromBytes(
          kind: LoanDocumentKind.validId,
          name: 'id.pdf',
          bytes: Uint8List(SelectedLoanDocument.maxBytes + 1),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Collateral is required only above 200,000; duplicate kinds are rejected',
    () {
      final pair = [
        document(LoanDocumentKind.payslip),
        document(LoanDocumentKind.validId),
      ];
      expect(() => validateLoanDocuments(pair, 200000), returnsNormally);
      expect(() => validateLoanDocuments(pair, 200001), throwsStateError);
      expect(
        () => validateLoanDocuments([
          ...pair,
          document(LoanDocumentKind.collateral),
        ], 200001),
        returnsNormally,
      );
      expect(
        () => validateLoanDocuments([pair.first, pair.first], 50000),
        throwsStateError,
      );
    },
  );
  test(
    'Files source reads a real byte stream instead of inventing a filename',
    () async {
      final service = DocumentPickerService(
        currentUserId: () => 'member-A',
        storage: MemorySecureStorage(),
        pickFiles: () async => FilePickerResult([
          PlatformFile(
            name: 'payslip.pdf',
            size: pdfBytes().length,
            readStream: Stream.value(pdfBytes()),
          ),
        ]),
      );
      final selected = await service.pick(
        LoanDocumentKind.payslip,
        DocumentSource.files,
      );
      expect(selected!.bytes, pdfBytes());
      expect(selected.name, 'payslip.pdf');
    },
  );
  test(
    'Camera and gallery route to the requested image source and clear recovery markers',
    () async {
      final storage = MemorySecureStorage();
      final seen = <DocumentSource>[];
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jnaIAAAAASUVORK5CYII=',
      );
      final service = DocumentPickerService(
        currentUserId: () => 'member-A',
        storage: storage,
        pickImage: (source) async {
          seen.add(source);
          return XFile.fromData(png, name: 'identity.png');
        },
      );
      for (final source in [DocumentSource.camera, DocumentSource.gallery]) {
        final selected = await service.pick(LoanDocumentKind.validId, source);
        expect(selected!.contentType, 'image/png');
        expect(selected.bytes, png);
      }
      expect(seen, [DocumentSource.camera, DocumentSource.gallery]);
      expect(storage.values['documents.pending_image_picker'], isNull);
    },
  );
  test(
    'Cancelling selection returns no replacement, permission errors are readable',
    () async {
      final cancelled = DocumentPickerService(
        currentUserId: () => 'member-A',
        storage: MemorySecureStorage(),
        pickFiles: () async => null,
      );
      expect(
        await cancelled.pick(LoanDocumentKind.payslip, DocumentSource.files),
        isNull,
      );
      final denied = DocumentPickerService(
        currentUserId: () => 'member-A',
        storage: MemorySecureStorage(),
        pickImage: (_) async =>
            throw PlatformException(code: 'camera_access_denied'),
      );
      await expectLater(
        denied.pick(LoanDocumentKind.validId, DocumentSource.camera),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('device settings'),
          ),
        ),
      );
    },
  );
  test(
    'An attachment is rejected if the signed-in account changes while picking',
    () async {
      var owner = 'member-A';
      final service = DocumentPickerService(
        currentUserId: () => owner,
        storage: MemorySecureStorage(),
        pickFiles: () async {
          owner = 'member-B';
          return FilePickerResult([
            PlatformFile(
              name: 'id.pdf',
              size: pdfBytes().length,
              bytes: pdfBytes(),
            ),
          ]);
        },
      );
      await expectLater(
        service.pick(LoanDocumentKind.validId, DocumentSource.files),
        throwsStateError,
      );
    },
  );
}
