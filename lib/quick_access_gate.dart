import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confirmpasscreen.dart';
import 'dashboard.dart';
import 'loginscreen.dart';
import 'quick_unlock_screen.dart';
import 'splashscreen.dart';
import 'security/quick_access_controller.dart';

class QuickAccessEntry extends StatelessWidget {
  const QuickAccessEntry({super.key, this.controller});
  final QuickAccessController? controller;

  @override
  Widget build(BuildContext context) {
    final access = controller ?? QuickAccessController.instance;
    return AnimatedBuilder(
      animation: access,
      builder: (context, _) {
        if (!access.ready || access.locked || access.redirectToStart) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!access.hasSession) {
          return access.loginMessage == null
              ? const Splashscreen()
              : LoginScreen(notice: access.loginMessage);
        }
        return access.requiresPasswordChange
            ? const ConfirmPassScreen()
            : const Dashboard();
      },
    );
  }
}

class QuickAccessGate extends StatefulWidget {
  const QuickAccessGate({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.controller,
    this.authEvents,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final QuickAccessController? controller;
  final Stream<AuthState>? authEvents;

  @override
  State<QuickAccessGate> createState() => _QuickAccessGateState();
}

class _QuickAccessGateState extends State<QuickAccessGate>
    with WidgetsBindingObserver {
  late final QuickAccessController _controller;
  StreamSubscription<AuthState>? _subscription;
  bool _redirectScheduled = false;
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? QuickAccessController.instance;
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleChange);
    _subscription =
        (widget.authEvents ?? Supabase.instance.client.auth.onAuthStateChange)
            .listen((event) {
              // Do not call SDK async methods while handling an Auth callback.
              scheduleMicrotask(() {
                if (mounted) {
                  _controller.handleAuthUserChanged(event.session?.user.id);
                }
              });
            });
    unawaited(_controller.initialize());
    _handleChange();
  }

  void _handleChange() {
    if (!_controller.redirectToStart || _redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectScheduled = false;
      if (!mounted || !_controller.redirectToStart) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) {
        _handleChange();
        return;
      }
      navigator.pushNamedAndRemoveUntil('/', (_) => false);
      _controller.acknowledgeRedirect();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgrounded = true;
      _controller.lock();
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      _controller.lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleChange);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final blocked =
          !_controller.ready ||
          _controller.locked ||
          _controller.redirectToStart;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: blocked,
            child: ExcludeFocus(
              excluding: blocked,
              child: TickerMode(enabled: !blocked, child: widget.child),
            ),
          ),
          if (!_controller.ready || _controller.redirectToStart)
            const Scaffold(body: Center(child: CircularProgressIndicator()))
          else if (_controller.locked)
            HeroControllerScope.none(
              child: Navigator(
                key: const ValueKey('quick-access-unlock'),
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => QuickUnlockScreen(controller: _controller),
                ),
              ),
            ),
        ],
      );
    },
  );
}
