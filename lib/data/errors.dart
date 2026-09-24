import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns backend and network failures into short sentences a person can act on.
String friendlyError(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case 'P0001':
        return error.message;
      case '23514':
        return 'That text is empty or too long.';
      case '42501':
        return 'You do not have access to that.';
      case 'PGRST301':
      case 'PGRST303':
        return 'Your session expired. Sign in again.';
    }
    if (error.message.isNotEmpty && error.message.length < 140) {
      return error.message;
    }
    return 'Something went wrong on the server. Try again.';
  }
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login')) {
      return 'Email or password is incorrect.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    return error.message;
  }
  if (error is ArgumentError) {
    return error.message.toString();
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest')) {
    return 'Network problem. Check your connection and try again.';
  }
  return 'Something went wrong. Try again.';
}

/// Server hint set by our SQL guards: muted, rate_limited, duplicate.
String? errorHint(Object error) =>
    error is PostgrestException ? error.hint : null;
