import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenshotProtection extends StatefulWidget {
  final Widget child;

  const ScreenshotProtection({super.key, required this.child});

  @override
  State<ScreenshotProtection> createState() => _ScreenshotProtectionState();
}

class _ScreenshotProtectionState extends State<ScreenshotProtection>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('coop_frontend/security');
  bool _showPrivacyOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableSecureWindow();
  }

  Future<void> _enableSecureWindow() async {
    try {
      await _channel.invokeMethod<void>('enableSecureWindow');
    } on MissingPluginException {
      // Desktop and web do not expose Android's secure-window API.
    } on PlatformException {
      // The lifecycle privacy overlay still protects the Flutter view.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldShowOverlay =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;

    if (shouldShowOverlay != _showPrivacyOverlay && mounted) {
      setState(() {
        _showPrivacyOverlay = shouldShowOverlay;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showPrivacyOverlay)
          const ColoredBox(
            color: Color(0xFF1A5E38),
            child: Center(
              child: Icon(Icons.lock_outline, color: Colors.white, size: 48),
            ),
          ),
      ],
    );
  }
}
