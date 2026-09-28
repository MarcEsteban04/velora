import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/pin_hasher.dart';

sealed class PinCheck {
  const PinCheck();
}

class PinAccepted extends PinCheck {
  const PinAccepted();
}

class PinRejected extends PinCheck {
  const PinRejected(this.attemptsLeft);

  /// Wrong tries left before a lockout starts.
  final int attemptsLeft;
}

class PinLockedOut extends PinCheck {
  const PinLockedOut(this.until);
  final DateTime until;
}

/// Stores the PIN hash in the OS keystore (Android Keystore or iOS Keychain)
/// and rate-limits wrong attempts.
///
/// The attempt counter is stored too, so killing the app doesn't reset it.
/// After [maxAttempts] wrong tries the PIN is locked for 30 seconds, and each
/// further wrong try doubles the wait.
class PinRepository {
  PinRepository(this._storage, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  static const maxAttempts = 5;
  static const _baseLockout = Duration(seconds: 30);

  static const _kSalt = 'pin.salt';
  static const _kHash = 'pin.hash';
  static const _kFailed = 'pin.failed';
  static const _kLockedUntil = 'pin.lockedUntil';

  Future<bool> hasPin() async => await _storage.read(key: _kHash) != null;

  Future<void> setPin(String pin) async {
    final salt = PinHasher.newSalt();
    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(
      key: _kHash,
      value: base64Encode(await _hash(pin, salt)),
    );
    await _resetAttempts();
  }

  /// The active lockout, if any. The lock screen uses it to resume a
  /// countdown after a restart.
  Future<DateTime?> lockedUntil() async {
    final raw = await _storage.read(key: _kLockedUntil);
    final until = raw == null ? null : DateTime.tryParse(raw);
    return until != null && until.isAfter(_now()) ? until : null;
  }

  Future<PinCheck> verify(String pin) async {
    final locked = await lockedUntil();
    if (locked != null) return PinLockedOut(locked);

    final salt = await _storage.read(key: _kSalt);
    final stored = await _storage.read(key: _kHash);
    if (salt == null || stored == null) return const PinRejected(0);

    final candidate = await _hash(pin, base64Decode(salt));
    if (PinHasher.constantTimeEquals(candidate, base64Decode(stored))) {
      await _resetAttempts();
      return const PinAccepted();
    }

    final failed = int.parse(await _storage.read(key: _kFailed) ?? '0') + 1;
    await _storage.write(key: _kFailed, value: '$failed');
    if (failed < maxAttempts) return PinRejected(maxAttempts - failed);

    final over = failed - maxAttempts;
    final until = _now().add(_baseLockout * pow(2, over).toInt());
    await _storage.write(key: _kLockedUntil, value: until.toIso8601String());
    return PinLockedOut(until);
  }

  Future<void> clear() => Future.wait([
    for (final k in [_kSalt, _kHash, _kFailed, _kLockedUntil])
      _storage.delete(key: k),
  ]);

  /// Hashes off the UI thread, so tapping the last digit never stutters.
  static Future<List<int>> _hash(String pin, List<int> salt) =>
      Isolate.run(() => PinHasher.hash(pin, salt));

  Future<void> _resetAttempts() async {
    await _storage.delete(key: _kFailed);
    await _storage.delete(key: _kLockedUntil);
  }
}

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(const FlutterSecureStorage()),
);
