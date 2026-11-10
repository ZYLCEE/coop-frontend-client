import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'quick_access_gate.dart';
import 'security/secure_auth_storage.dart';
import 'security/device_security_service.dart';
import 'security/screenshot_protection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  final configurationError = _supabaseConfigurationError(
    supabaseUrl: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  if (configurationError != null) {
    runApp(SupabaseConfigurationErrorApp(message: configurationError));
    return;
  }

  final configuredUrl = supabaseUrl!;
  final configuredAnonKey = supabaseAnonKey!;
  final projectRef = Uri.parse(configuredUrl).host.split('.').first;
  await Supabase.initialize(
    url: configuredUrl,
    publishableKey: configuredAnonKey,
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

String? _supabaseConfigurationError({
  required String? supabaseUrl,
  required String? anonKey,
}) {
  final uri = supabaseUrl == null ? null : Uri.tryParse(supabaseUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return 'Set SUPABASE_URL in the app’s .env file to your Supabase project URL.';
  }

  if (anonKey == null ||
      anonKey.isEmpty ||
      RegExp(
        r'^(your_|placeholder|replace|<)',
        caseSensitive: false,
      ).hasMatch(anonKey)) {
    return 'Replace the placeholder SUPABASE_ANON_KEY in the app’s .env file '
        'with this project’s current anon/publishable key. Never use a '
        'service-role key in the app.';
  }

  return null;
}

class SupabaseConfigurationErrorApp extends StatelessWidget {
  const SupabaseConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSUCCERMPC setup',
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Supabase is not configured',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryGreen),
        scaffoldBackgroundColor: AppTheme.background,
        fontFamily: AppTheme.fontFamily,
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
