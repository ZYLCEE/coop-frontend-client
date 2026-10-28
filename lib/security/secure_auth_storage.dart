import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage({
    required this.sessionKey,
    SecureStorageService? storage,
    this.previousStorage,
  }) : _storage = storage ?? SecureStorageService();

  final String sessionKey;
  final SecureStorageService _storage;
  final LocalStorage? previousStorage;

  @override
  Future<void> initialize() async {
    final previous = previousStorage;
    if (previous == null) return;
    await previous.initialize();
    if (await accessToken() == null) {
      final oldSession = await previous.accessToken();
      if (oldSession != null) await persistSession(oldSession);
    }
    await previous.removePersistedSession();
  }

  @override
  Future<String?> accessToken() => _storage.read(sessionKey);

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (!await _storage.write(sessionKey, persistSessionString)) {
      throw StateError('Unable to securely save the member session.');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    if (!await _storage.delete(sessionKey)) {
      throw StateError('Unable to clear the stored member session.');
    }
  }
}
