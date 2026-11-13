import 'package:coop_frontend/services/demo_loan_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Demo challenges require an enabled session, expire, and are single use',
    () {
      var enabled = false;
      var now = DateTime.utc(2026);
      final service = DemoLoanConsentService(
        enabled: () => enabled,
        now: () => now,
      );
      const code = DemoLoanConsentService.sampleCode;
      expect(service.issue(), false);
      expect(service.verify(code), DemoOtpResult.unavailable);
      enabled = true;
      expect(service.issue(), true);
      expect(service.verify('87654321'), DemoOtpResult.invalid);
      now = now.add(DemoLoanConsentService.lifetime);
      expect(service.verify(code), DemoOtpResult.expired);
      expect(service.issue(), true);
      expect(service.verify(code), DemoOtpResult.confirmed);
      expect(service.verify(code), DemoOtpResult.unavailable);
      expect(service.issue(), true);
      enabled = false;
      expect(service.verify(code), DemoOtpResult.unavailable);
    },
  );
}
