import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'security/quick_access_controller.dart';
import 'security/quick_access_service.dart';

class QuickAccessSetupScreen extends StatefulWidget {
  const QuickAccessSetupScreen({super.key, this.controller, this.onCompleted});
  final QuickAccessController? controller;
  final VoidCallback? onCompleted;

  @override
  State<QuickAccessSetupScreen> createState() => _QuickAccessSetupScreenState();
}

class _QuickAccessSetupScreenState extends State<QuickAccessSetupScreen> {
  static const _green = Color(0xFF1A5E38);
  late final QuickAccessController _controller;
  bool _biometricSelected = false;
  bool _biometricsAvailable = false;
  bool _checkingBiometrics = true;
  bool _busy = false;
  String _pin = '';
  String? _firstPin;
  String? _error;

  bool get _canSetup =>
      _controller.hasSession &&
      _controller.userId != null &&
      !_controller.requiresPasswordChange;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? QuickAccessController.instance;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final owner = _controller.userId;
      final method = owner == null
          ? QuickAccessMethod.none
          : await _controller.service.methodFor(owner);
      final available = await _controller.service.biometrics.isAvailable();
      if (!mounted) return;
      setState(() {
        _biometricSelected = method == QuickAccessMethod.biometric;
        _biometricsAvailable = available;
        _checkingBiometrics = false;
        if (!_canSetup) {
          _error =
              'Sign in and complete password setup before enabling quick access.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingBiometrics = false;
        _error = 'Unable to check quick-access settings. Please try again.';
      });
    }
  }

  Future<void> _finish() async {
    await _controller.settingsChanged();
    if (!mounted) return;
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
        (_) => false,
      );
    }
  }

  Future<void> _skip() async {
    if (_busy || !_canSetup) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.service.skip(_controller.userId!);
      await _finish();
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is StateError
              ? failure.message
              : 'Unable to skip quick-access setup. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enrollBiometrics() async {
    if (_busy || !_canSetup || _checkingBiometrics) return;
    setState(() {
      _biometricSelected = true;
      _busy = true;
      _error = null;
      _pin = '';
      _firstPin = null;
    });
    try {
      final enrolled = await _controller.service.enrollBiometrics(
        _controller.userId!,
      );
      if (enrolled) {
        await _finish();
      } else if (mounted) {
        setState(
          () => _error =
              'Biometric setup was cancelled. Try again, choose PIN, or skip.',
        );
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is StateError
              ? failure.message
              : 'Biometric setup failed. Choose PIN or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onNumberPressed(String number) async {
    if (_busy || !_canSetup || _pin.length >= 4) return;
    setState(() {
      _pin += number;
      _error = null;
    });
    if (_pin.length != 4) return;
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _firstPin = null;
        _error = 'PINs do not match. Enter a new PIN and confirm it.';
      });
      return;
    }
    final pin = _pin;
    setState(() {
      _busy = true;
      _pin = '';
      _firstPin = null;
    });
    try {
      await _controller.service.enrollPin(_controller.userId!, pin);
      await _finish();
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is StateError
              ? failure.message
              : 'Unable to save your PIN. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pin = '';
    _firstPin = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _busy || !_canSetup ? null : _skip,
              child: const Text('Skip'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Access Setup',
                      style: TextStyle(
                        color: _green,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a faster unlock method for future sessions, or skip to use your Member ID and password.',
                      style: TextStyle(color: _green, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _busy || !_canSetup || _checkingBiometrics
                                ? null
                                : _enrollBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Biometric'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _biometricSelected
                                  ? Colors.white
                                  : _green,
                              backgroundColor: _biometricSelected
                                  ? _green
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy || !_canSetup
                                ? null
                                : () => setState(() {
                                    _biometricSelected = false;
                                    _pin = '';
                                    _firstPin = null;
                                    _error = null;
                                  }),
                            icon: const Icon(Icons.lock),
                            label: const Text('PIN'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: !_biometricSelected
                                  ? Colors.white
                                  : _green,
                              backgroundColor: !_biometricSelected
                                  ? _green
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_checkingBiometrics)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Checking biometric availability...'),
                      ),
                    if (!_checkingBiometrics && !_biometricsAvailable)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'No enrolled biometrics available. You can use PIN or skip setup.',
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!_biometricSelected) ...[
                      const SizedBox(height: 24),
                      Text(
                        _firstPin == null
                            ? 'ENTER 4-DIGIT PIN'
                            : 'CONFIRM YOUR 4-DIGIT PIN',
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _pin.length
                                  ? _green
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final row in [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                        ['', '0', 'back'],
                      ])
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row
                              .map(
                                (number) => SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: number.isEmpty
                                      ? null
                                      : TextButton(
                                          onPressed: _busy || !_canSetup
                                              ? null
                                              : number == 'back'
                                              ? () => setState(() {
                                                  if (_pin.isNotEmpty) {
                                                    _pin = _pin.substring(
                                                      0,
                                                      _pin.length - 1,
                                                    );
                                                  }
                                                })
                                              : () => _onNumberPressed(number),
                                          child: number == 'back'
                                              ? const Icon(
                                                  Icons.backspace_outlined,
                                                )
                                              : Text(
                                                  number,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    color: _green,
                                                  ),
                                                ),
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
