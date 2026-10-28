import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quick_access_gate.dart';
import 'security/secure_auth_storage.dart';
import 'security/device_security_service.dart';
import 'security/screenshot_protection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureAuthStorage(
        sessionKey: 'auth.supabase_session.$projectRef',
        previousStorage: SharedPreferencesLocalStorage(
          persistSessionKey: 'sb-$projectRef-auth-token',
        ),
      ),
    ),
  );
  runApp(const MyApp());
  unawaited(_reportDeviceSecurityStatus());
}

Future<void> _reportDeviceSecurityStatus() async {
  final status = await DeviceSecurityService().check();
  if (kDebugMode) {
    debugPrint(status.debugSummary);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'CSUCCERMPC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A5E38)),
      ),
      builder: (context, child) => ScreenshotProtection(
        child: QuickAccessGate(
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const QuickAccessEntry(),
    );
  }
}
