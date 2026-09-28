import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velora/core/errors/friendly_error.dart';

void main() {
  test('only real network failures blame the connection', () {
    expect(
      friendlyError(const SocketException('no route')),
      contains('offline'),
    );
    expect(
      friendlyError(http.ClientException('lookup failed')),
      contains('offline'),
    );
  });

  test('auth and server errors do not blame the connection', () {
    const auth = AuthException('Anonymous sign-ins are disabled');
    expect(friendlyError(auth), isNot(contains('offline')));
    expect(
      friendlyError(const PostgrestException(message: 'boom')),
      contains('on our side'),
    );
  });
}
