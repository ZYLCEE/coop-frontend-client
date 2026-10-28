import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pin_security_service.dart';
import 'quick_access_service.dart';

class InvalidQuickAccessSession implements Exception {
  const InvalidQuickAccessSession(this.message);
  final String message;
}

class QuickAccessController extends ChangeNotifier {
  QuickAccessController({
    QuickAccessService? service,
    String? Function()? currentUserId,
    Future<bool> Function(String userId)? validateSession,
    Future<void> Function()? endSession,
  }) : service = service ?? QuickAccessService(),
       _currentUserId =
           currentUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id),
       _validateSession = validateSession ?? _validateSupabaseSession,
       _endSession =
           endSession ??
           (() => Supabase.instance.client.auth.signOut(
             scope: SignOutScope.local,
           ));

  static final instance = QuickAccessController();
  final QuickAccessService service;
  final String? Function() _currentUserId;
  final Future<bool> Function(String userId) _validateSession;
  final Future<void> Function() _endSession;

  bool ready = false;
  bool hasSession = false;
  bool locked = false;
  bool busy = false;
  bool requiresPasswordChange = false;
  bool redirectToStart = false;
  String? userId;
  String? error;
  String? loginMessage;
  QuickAccessMethod method = QuickAccessMethod.none;
  bool _initializing = false;
  int _generation = 0;

  bool get enabled =>
      method == QuickAccessMethod.pin || method == QuickAccessMethod.biometric;

  Future<void> initialize() async {
    if (ready || _initializing) return;
    _initializing = true;
    try {
      userId = _currentUserId();
      if (userId != null) {
        method = await service.methodFor(userId!);
        if (enabled) {
          hasSession = true;
          locked = true;
        } else {
          // Skipped/unconfigured quick access always requires password login
          // on the next app launch, even if the SDK restored an old session.
          await _endSession();
          userId = null;
        }
      }
    } catch (_) {
      hasSession = false;
      userId = null;
      loginMessage =
          'Unable to restore quick access. Please sign in with your Member ID and password.';
    } finally {
      _initializing = false;
      ready = true;
      notifyListeners();
    }
  }

  Future<void> activateAfterPasswordLogin({
    required bool mustChangePassword,
  }) async {
    final current = _currentUserId();
    if (current == null) {
      throw StateError('Please sign in before setting up quick access.');
    }
    final configured = await service.methodFor(current);
    if (configured == QuickAccessMethod.none) await service.clear();
    _generation++;
    userId = current;
    method = configured;
    hasSession = true;
    ready = true;
    locked = false;
    busy = false;
    requiresPasswordChange = mustChangePassword;
    redirectToStart = false;
    error = null;
    loginMessage = null;
    notifyListeners();
  }

  Future<void> settingsChanged() async {
    final current = _currentUserId();
    if (current == null || current != userId) {
      throw StateError('Please sign in again.');
    }
    method = await service.methodFor(current);
    locked = false;
    error = null;
    notifyListeners();
  }

  void lock() {
    if (!ready || !hasSession || !enabled || locked) return;
    locked = true;
    error = null;
    notifyListeners();
  }

  void handleAuthUserChanged(String? current) {
    if (_initializing || !ready || !hasSession) return;
    if (current != userId) {
      _requireLogin('Your session has ended. Please sign in again.');
    }
  }

  void _requireLogin(String? message) {
    _generation++;
    userId = null;
    hasSession = false;
    method = QuickAccessMethod.none;
    locked = true;
    busy = false;
    requiresPasswordChange = false;
    redirectToStart = true;
    loginMessage = message;
    error = null;
    notifyListeners();
  }

  void acknowledgeRedirect() {
    redirectToStart = false;
    locked = false;
    notifyListeners();
  }

  Future<void> usePasswordLogin() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await _endSession();
      _requireLogin('Sign in with your Member ID and password.');
    } catch (_) {
      busy = false;
      error = 'Unable to switch to password login. Please try again.';
      notifyListeners();
    }
  }

  Future<void> clearAfterSignOut() async {
    try {
      await service.clear();
    } finally {
      _requireLogin(null);
    }
  }

  Future<void> unlockWithPin(String pin) => _unlock(() async {
    final result = await service.verifyPin(userId!, pin);
    switch (result) {
      case PinVerificationResult.success:
        return true;
      case PinVerificationResult.incorrect:
        throw StateError('Incorrect PIN. Please try again.');
      case PinVerificationResult.temporarilyDisabled:
        throw StateError(
          'Too many incorrect PIN attempts. Try again in 5 minutes or use your password.',
        );
      case PinVerificationResult.invalidPin:
        throw StateError('Enter your 4-digit PIN.');
      case PinVerificationResult.notEnrolled:
        throw StateError(
          'PIN access is unavailable for this account. Use your password.',
        );
      case PinVerificationResult.storageError:
        throw StateError('Unable to read your PIN. Use your password.');
    }
  });

  Future<void> unlockWithBiometrics() =>
      _unlock(() => service.verifyBiometrics(userId!));

  Future<void> _unlock(Future<bool> Function() authenticate) async {
    if (busy || !locked || !hasSession || userId == null) return;
    final expectedUser = userId!;
    final generation = _generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (_currentUserId() != expectedUser) {
        throw const InvalidQuickAccessSession('Please sign in again.');
      }
      final authenticated = await authenticate();
      if (generation != _generation) return;
      if (!authenticated) {
        error =
            'Authentication was cancelled or not recognized. Try again or use your password.';
        return;
      }
      // A local PIN/fingerprint unlocks only the matching, server-validated
      // member session. It never replaces Supabase authentication.
      final mustChangePassword = await _validateSession(expectedUser);
      if (generation != _generation) return;
      if (_currentUserId() != expectedUser) {
        throw const InvalidQuickAccessSession(
          'Your account changed. Please sign in again.',
        );
      }
      requiresPasswordChange = mustChangePassword;
      if (mustChangePassword) {
        redirectToStart = true;
      } else {
        locked = false;
      }
    } on InvalidQuickAccessSession catch (failure) {
      if (generation != _generation) return;
      try {
        await _endSession();
      } catch (_) {
        /* Still require password login. */
      }
      _requireLogin(failure.message);
    } catch (failure) {
      if (generation == _generation) {
        error = failure is StateError
            ? failure.message
            : 'Unable to unlock your account. Check your connection and try again.';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  static Future<bool> _validateSupabaseSession(String expectedUser) async {
    final client = Supabase.instance.client;
    try {
      if (client.auth.currentUser?.id != expectedUser) {
        throw const InvalidQuickAccessSession(
          'Please sign in with your Member ID and password.',
        );
      }
      final refreshed = await client.auth.refreshSession();
      if (refreshed.session == null) {
        throw const InvalidQuickAccessSession(
          'Your session expired. Please sign in again.',
        );
      }
      final response = await client.auth.getUser();
      final user = response.user;
      if (user == null ||
          user.id != expectedUser ||
          user.appMetadata['role'] != 'member' ||
          (user.appMetadata['account_status'] != null &&
              user.appMetadata['account_status'] != 'active')) {
        throw const InvalidQuickAccessSession(
          'An active member account is required. Please sign in again.',
        );
      }
      final profile = await client
          .from('members')
          .select('status, must_change_password')
          .eq('user_id', expectedUser)
          .maybeSingle();
      if (profile == null || profile['status'] != 'active') {
        throw const InvalidQuickAccessSession(
          'Your member account is unavailable. Please contact the cooperative admin.',
        );
      }
      return profile['must_change_password'] == true;
    } on AuthException catch (failure) {
      if (['400', '401', '403'].contains(failure.statusCode)) {
        throw const InvalidQuickAccessSession(
          'Your session expired. Please sign in again.',
        );
      }
      throw StateError(
        'Unable to validate your session. Check your internet connection and retry.',
      );
    }
  }
}
