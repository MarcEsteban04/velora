/// Rules for choosing a PIN.
abstract final class PinPolicy {
  static const length = 4;

  /// Rejects the PINs people guess first: one repeated digit (1111), a
  /// straight run up or down (1234, 9876), and a repeated pair (1212).
  static bool isTooSimple(String pin) {
    if (pin.length != length) return false;
    final d = pin.split('').map(int.parse).toList();
    final allSame = d.every((x) => x == d.first);
    bool run(int step) =>
        [for (var i = 1; i < d.length; i++) i]
            .every((i) => d[i] - d[i - 1] == step);
    final repeatedPair = d[0] == d[2] && d[1] == d[3];
    return allSame || run(1) || run(-1) || repeatedPair;
  }
}
