import 'package:supabase_flutter/supabase_flutter.dart';

String getAuthErrorMessage(Object error) {
  final message = error is StateError
      ? error.message
      : error is AuthException
      ? error.message
      : error.toString();
  final normalizedMessage = message.toLowerCase();

  if (normalizedMessage.contains('user_banned') ||
      normalizedMessage.contains('banned') ||
      normalizedMessage.contains('blocked') ||
      normalizedMessage.contains('suspended') ||
      normalizedMessage.contains('inactive member') ||
      normalizedMessage.contains('member account is inactive')) {
    return 'Your account has been blocked by the administrators. Please contact the cooperative administrators for assistance.';
  }

  if (error is StateError) return error.message;

  if (normalizedMessage.contains('invalid api key') ||
      normalizedMessage.contains('invalid api_key')) {
    return 'Supabase rejected the project key. Check SUPABASE_ANON_KEY in the app’s .env file.';
  }

  if (normalizedMessage.contains('invalid_credentials') ||
      normalizedMessage.contains('invalid login credential')) {
    return 'No account found or the password is incorrect.';
  }

  if (normalizedMessage.contains('email not confirmed')) {
    return 'Please confirm your email before logging in.';
  }

  if (normalizedMessage.contains('network') ||
      normalizedMessage.contains('socket') ||
      normalizedMessage.contains('failed host lookup')) {
    return 'Cannot connect to the login server. Please check your internet connection.';
  }

  return 'Login failed. Please try again.';
}
