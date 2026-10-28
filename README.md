# coop_frontend

A new Flutter project.

## Quick Access Setup

After first-login password setup, members can enroll a confirmed 4-digit PIN,
enroll device biometrics, or skip. The same settings are available from
**My Profile → Change PIN / Biometric**.

- Enrolled accounts see a quick-unlock screen on app startup and after the app
  returns from the background. Screens beneath the lock cannot receive input.
- A correct PIN or successful biometric prompt is followed by a Supabase session
  refresh and a check of the member's current role, status, and password-reset
  flag. An internet connection is required to complete that check.
- Five incorrect PIN attempts disable PIN verification for five minutes. The
  password sign-in option is available if a PIN is forgotten, biometrics are
  unavailable, or a saved session has expired.
- Skipping continues to the dashboard for the current session and uses normal
  Member ID/password login at the next launch.
- Quick-access settings are bound to the authenticated account. Signing out
  clears the PIN/biometric enrollment on this device.
- Supabase sessions are persisted in encrypted device storage alongside the
  protected PIN verifier. Existing SDK session storage is migrated on startup.

Android uses `FlutterFragmentActivity` and the biometric permission. iOS has a
Face ID usage description. After native changes, rebuild/reinstall with
`flutter run`; hot reload alone cannot apply them. Biometrics must be enrolled
in the device's operating-system settings.

Run automated coverage with `flutter test`. Biometric prompt behavior should
also be exercised on a physical device with an enrolled fingerprint or face.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
