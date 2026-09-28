import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256, so the PIN is never stored as plain text.
///
/// A 4-digit PIN has only 10,000 possibilities, so hashing alone can't stop
/// an attacker who can read the hash. The real protection is layered: the
/// hash lives in the OS keystore (see `PinRepository`), and wrong attempts
/// are rate-limited. Hashing makes sure the raw PIN is never written anywhere.
abstract final class PinHasher {
  static const _iterations = 20000;
  static const _saltLength = 16;

  static Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  static Uint8List hash(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    // One 32-byte block is enough: the output length equals SHA-256's.
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(block);
    for (var i = 1; i < _iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }

  /// Compares every byte even after a mismatch, so response time doesn't
  /// reveal how much of the hash matched.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
