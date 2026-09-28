import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/security/pin_policy.dart';
import 'package:velora/features/app_lock/data/pin_repository.dart';

void main() {
  group('PinPolicy.isTooSimple', () {
    test('rejects the PINs people guess first', () {
      for (final pin in [
        '0000',
        '1111',
        '1234',
        '6789',
        '9876',
        '4321',
        '1212',
      ]) {
        expect(PinPolicy.isTooSimple(pin), isTrue, reason: pin);
      }
    });

    test('accepts ordinary PINs', () {
      for (final pin in ['2580', '1379', '8052', '1122']) {
        expect(PinPolicy.isTooSimple(pin), isFalse, reason: pin);
      }
    });
  });

  group('PinRepository', () {
    late DateTime now;
    late PinRepository pins;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      now = DateTime(2026, 9, 28, 12);
      pins = PinRepository(const FlutterSecureStorage(), clock: () => now);
    });

    test('never stores the PIN in plain text', () async {
      await pins.setPin('2580');
      final all = await const FlutterSecureStorage().readAll();
      expect(all.values.any((v) => v.contains('2580')), isFalse);
      expect(await pins.hasPin(), isTrue);
    });

    test('accepts the right PIN and counts down wrong ones', () async {
      await pins.setPin('2580');
      expect(await pins.verify('2580'), isA<PinAccepted>());

      final first = await pins.verify('0001');
      expect(
        (first as PinRejected).attemptsLeft,
        PinRepository.maxAttempts - 1,
      );
    });

    test('locks out after too many tries and doubles the wait', () async {
      await pins.setPin('2580');
      PinCheck result = const PinAccepted();
      for (var i = 0; i < PinRepository.maxAttempts; i++) {
        result = await pins.verify('0001');
      }
      final lock = result as PinLockedOut;
      expect(lock.until, now.add(const Duration(seconds: 30)));

      // Even the right PIN is refused during a lockout.
      expect(await pins.verify('2580'), isA<PinLockedOut>());

      // After it expires, another miss locks for twice as long.
      now = now.add(const Duration(seconds: 31));
      final second = await pins.verify('0001') as PinLockedOut;
      expect(second.until, now.add(const Duration(seconds: 60)));
    });

    test('a correct PIN resets the attempt counter', () async {
      await pins.setPin('2580');
      await pins.verify('0001');
      await pins.verify('0002');
      await pins.verify('2580');
      final next = await pins.verify('0003') as PinRejected;
      expect(next.attemptsLeft, PinRepository.maxAttempts - 1);
    });

    test('clear removes everything', () async {
      await pins.setPin('2580');
      await pins.clear();
      expect(await pins.hasPin(), isFalse);
    });
  });
}
