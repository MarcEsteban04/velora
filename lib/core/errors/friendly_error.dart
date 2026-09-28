import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when the device couldn't talk to the server at all.
bool isNetworkError(Object error) =>
    error is SocketException ||
    error is http.ClientException ||
    error is TimeoutException;

/// True when the database refused a duplicate (a unique constraint).
bool isDuplicateError(Object error) =>
    error is PostgrestException && error.code == '23505';

/// Turns an exception into a message a person can act on, and logs the real
/// error for developers. Only genuine network failures blame the connection.
/// Anything else is our problem, and saying otherwise sends users on a wild
/// goose chase.
String friendlyError(Object error, {String action = 'save that'}) {
  developer.log('Failed to $action', name: 'velora', error: error);
  // Also in the `flutter run` console, where developer.log doesn't show.
  if (kDebugMode) debugPrint('velora: failed to $action: $error');

  if (isNetworkError(error)) {
    return 'You seem to be offline. Check your connection and try again.';
  }
  if (isDuplicateError(error)) {
    return 'That name is already taken. Try a different one.';
  }
  if (error is AuthException) {
    return "We couldn't set up your private space right now. Please try "
        'again in a moment.';
  }
  return "Something went wrong on our side and we couldn't $action. Please "
      'try again.';
}
