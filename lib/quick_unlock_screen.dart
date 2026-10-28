import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'security/quick_access_controller.dart';
import 'security/quick_access_service.dart';

class QuickUnlockScreen extends StatefulWidget {
  const QuickUnlockScreen({super.key, required this.controller});
  final QuickAccessController controller;

  @override
  State<QuickUnlockScreen> createState() => _QuickUnlockScreenState();
}

class _QuickUnlockScreenState extends State<QuickUnlockScreen> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlockPin() async {
    await widget.controller.unlockWithPin(_pin.text);
    if (mounted) _pin.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final biometric = controller.method == QuickAccessMethod.biometric;
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFFE8F5E9),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          biometric ? Icons.fingerprint : Icons.lock_outline,
                          size: 64,
                          color: const Color(0xFF1A5E38),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Unlock your account',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          biometric
                              ? 'Use your enrolled device biometrics to continue.'
                              : 'Enter your 4-digit quick-access PIN to continue.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (!biometric)
                          TextField(
                            controller: _pin,
                            enabled: !controller.busy,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '4-digit PIN',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onSubmitted: (_) => _unlockPin(),
                          ),
                        if (controller.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              controller.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: controller.busy
                                ? null
                                : biometric
                                ? controller.unlockWithBiometrics
                                : _unlockPin,
                            child: controller.busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    biometric
                                        ? 'Unlock with biometrics'
                                        : 'Unlock',
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : controller.usePasswordLogin,
                          child: const Text(
                            'Use Member ID and password instead',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
