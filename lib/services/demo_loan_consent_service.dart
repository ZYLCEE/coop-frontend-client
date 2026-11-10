enum DemoOtpResult { confirmed, invalid, expired, unavailable }

/// A local, single-use simulation. No network or persistent storage.
class DemoLoanConsentService {
  DemoLoanConsentService({
    required bool Function() enabled,
    DateTime Function()? now,
  }) : _enabled = enabled,
       _now = now ?? DateTime.now;

  static const sampleCode = '12345678';
  static const lifetime = Duration(minutes: 1);

  final bool Function() _enabled;
  final DateTime Function() _now;
  DateTime? _expiresAt;

  bool issue() {
    if (!_enabled()) return false;
    _expiresAt = _now().add(lifetime);
    return true;
  }

  DemoOtpResult verify(String code) {
    final expiration = _expiresAt;
    if (!_enabled() || expiration == null) return DemoOtpResult.unavailable;
    if (!_now().isBefore(expiration)) return DemoOtpResult.expired;
    if (code != sampleCode) return DemoOtpResult.invalid;
    _expiresAt = null;
    return DemoOtpResult.confirmed;
  }
}
