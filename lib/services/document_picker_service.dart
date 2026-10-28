import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan_document.dart';
import '../security/secure_storage_service.dart';

class DocumentPickerService {
  DocumentPickerService({
    ImagePicker? images,
    Future<FilePickerResult?> Function()? pickFiles,
    Future<XFile?> Function(DocumentSource source)? pickImage,
    SecureStorageService? storage,
    String? Function()? currentUserId,
  }) : _images = images ?? ImagePicker(),
       _pickFiles = pickFiles,
       _pickImage = pickImage,
       _storage = storage ?? SecureStorageService(),
       _currentUserId =
           currentUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id);

  final ImagePicker _images;
  final Future<FilePickerResult?> Function()? _pickFiles;
  final Future<XFile?> Function(DocumentSource source)? _pickImage;
  final SecureStorageService _storage;
  final String? Function() _currentUserId;
  static const _pendingKey = 'documents.pending_image_picker';

  Future<SelectedLoanDocument?> pick(
    LoanDocumentKind kind,
    DocumentSource source,
  ) async {
    final owner = _currentUserId();
    if (owner == null)
      throw StateError('Please sign in before selecting documents.');
    try {
      SelectedLoanDocument? selected;
      if (source == DocumentSource.files) {
        final result = _pickFiles != null
            ? await _pickFiles()
            : await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: SelectedLoanDocument.supportedExtensions,
                allowMultiple: false,
                withData: false,
                withReadStream: true,
              );
        if (result == null) return null;
        final file = result.files.single;
        if (file.size > SelectedLoanDocument.maxBytes)
          throw StateError('Choose a file no larger than 10 MB.');
        Uint8List data;
        if (file.bytes != null) {
          data = file.bytes!;
        } else if (file.readStream != null) {
          final buffer = BytesBuilder(copy: false);
          await for (final chunk in file.readStream!) {
            if (buffer.length + chunk.length > SelectedLoanDocument.maxBytes)
              throw StateError('Choose a file no larger than 10 MB.');
            buffer.add(chunk);
          }
          data = buffer.takeBytes();
        } else if (file.path != null) {
          data = await XFile(file.path!).readAsBytes();
        } else {
          throw StateError(
            'Unable to read the selected file. Please choose it again.',
          );
        }
        selected = SelectedLoanDocument.fromBytes(
          kind: kind,
          name: file.name,
          bytes: data,
        );
      } else {
        if (!await _storage.write(
          _pendingKey,
          jsonEncode({'userId': owner, 'kind': kind.name}),
        )) {
          throw StateError(
            'Unable to prepare document selection. Please try again.',
          );
        }
        try {
          final image = _pickImage != null
              ? await _pickImage(source)
              : await _images.pickImage(
                  source: source == DocumentSource.camera
                      ? ImageSource.camera
                      : ImageSource.gallery,
                );
          if (image == null) return null;
          selected = await _fromImage(kind, image);
        } finally {
          await _storage.delete(_pendingKey);
        }
      }
      if (_currentUserId() != owner)
        throw StateError(
          'Your account changed. Sign in again before selecting documents.',
        );
      return selected;
    } on PlatformException catch (failure) {
      if (failure.code.toLowerCase().contains('access') ||
          failure.code.toLowerCase().contains('permission')) {
        throw StateError(
          'Allow camera/photo access in your device settings, or choose Files.',
        );
      }
      throw StateError(
        'Unable to open the selected source. Please try another option.',
      );
    } on UnsupportedError {
      throw StateError(
        'This source is unavailable on this device. Please choose Gallery or Files.',
      );
    }
  }

  Future<SelectedLoanDocument> _fromImage(
    LoanDocumentKind kind,
    XFile image,
  ) async {
    if (await image.length() > SelectedLoanDocument.maxBytes)
      throw StateError('Choose a file no larger than 10 MB.');
    final bytes = await image.readAsBytes();
    var name = image.name.trim();
    if (name.isEmpty) {
      final pathName = image.path.split(RegExp(r'[/\\]')).last.trim();
      name = pathName;
    }
    if (name.isEmpty || !name.contains('.')) {
      final extension = _extensionFromImageBytes(bytes);
      name = 'camera_${DateTime.now().millisecondsSinceEpoch}.$extension';
    }
    return SelectedLoanDocument.fromBytes(kind: kind, name: name, bytes: bytes);
  }

  String _extensionFromImageBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255)
      return 'jpg';
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10')
      return 'png';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP')
      return 'webp';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.skip(4).take(4)) == 'ftyp') {
      final brand = String.fromCharCodes(bytes.skip(8).take(4));
      if (brand.startsWith('hei')) return 'heic';
      if (brand == 'mif1' || brand == 'msf1') return 'heif';
    }
    throw StateError(
      'The selected image format is not supported. Choose JPG, PNG, WEBP, HEIC, or HEIF.',
    );
  }

  Future<SelectedLoanDocument?> recoverLostSelection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final pending = await _storage.read(_pendingKey);
    if (pending == null) return null;
    final recovered = await _images.retrieveLostData();
    await _storage.delete(_pendingKey);
    if (recovered.isEmpty) return null;
    final marker = jsonDecode(pending);
    if (marker is! Map || marker['userId'] != _currentUserId()) return null;
    if (recovered.exception != null)
      throw StateError(
        'Image selection was interrupted. Please select the document again.',
      );
    final kinds = LoanDocumentKind.values.where(
      (kind) => kind.name == marker['kind'],
    );
    if (kinds.isEmpty || recovered.files == null || recovered.files!.isEmpty)
      return null;
    return _fromImage(kinds.single, recovered.files!.first);
  }
}
