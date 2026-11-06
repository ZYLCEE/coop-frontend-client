import 'package:flutter/material.dart';
import 'security/quick_access_controller.dart';
import 'security/quick_access_service.dart';

class QuickUnlockScreen extends StatefulWidget {
  const QuickUnlockScreen({super.key, required this.controller});
  final QuickAccessController controller;

  @override
  State<QuickUnlockScreen> createState() => _QuickUnlockScreenState();
}

class _QuickUnlockScreenState extends State<QuickUnlockScreen> {
  String _pin = '';

  Future<void> _unlockPin() async {
    if (_pin.length != 4 || widget.controller.busy) return;
    final pin = _pin;
    setState(() => _pin = '');
    await widget.controller.unlockWithPin(pin);
  }

  void _pressDigit(String digit) {
    if (widget.controller.busy || _pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) _unlockPin();
  }

  void _eraseDigit() {
    if (widget.controller.busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _pinKey(String digit) => SizedBox(
    width: 72,
    height: 64,
    child: TextButton(
      onPressed: widget.controller.busy ? null : () => _pressDigit(digit),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 24, color: Color(0xFF1A5E38)),
      ),
    ),
  );

  Widget _pinKeypad() => Column(
    children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map(_pinKey).toList(),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 72),
          _pinKey('0'),
          SizedBox(
            width: 72,
            height: 64,
            child: IconButton(
              onPressed: widget.controller.busy ? null : _eraseDigit,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _pinDots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      4,
      (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: index < _pin.length
              ? const Color(0xFF1A5E38)
              : Colors.transparent,
          border: Border.all(color: const Color(0xFF1A5E38), width: 2),
        ),
      ),
    ),
  );

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
                        if (!biometric) ...[
                          _pinDots(),
                          const SizedBox(height: 18),
                          _pinKeypad(),
                        ],
                        if (controller.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              controller.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (biometric) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: controller.busy
                                  ? null
                                  : controller.unlockWithBiometrics,
                              child: controller.busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Unlock with biometrics'),
                            ),
                          ),
                        ],
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
