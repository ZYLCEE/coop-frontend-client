import 'package:supabase_flutter/supabase_flutter.dart';

String getAuthErrorMessage(Object error) {
  if (error is StateError) return error.message;
  final message = error is AuthException ? error.message : error.toString();
  final normalizedMessage = message.toLowerCase();

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
