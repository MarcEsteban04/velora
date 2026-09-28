import 'dart:math' as math;

/// The entry screen's calculator. It holds what the user typed (for example
/// `150 + 45.5`) and evaluates it to minor units, honouring × and ÷ before
/// + and −. Everything runs in integer minor units, so there's no
/// floating-point drift in money.
class AmountExpression {
  const AmountExpression([this.text = '']);

  final String text;

  static const operators = ['+', '−', '×', '÷'];

  bool get isEmpty => text.isEmpty;
  bool get hasOperator => operators.any(text.contains);

  String get _lastNumber {
    final parts = text.split(RegExp('[+−×÷]'));
    return parts.isEmpty ? '' : parts.last;
  }

  AmountExpression digit(String d, {required int decimalDigits}) {
    final number = _lastNumber;
    final dot = number.indexOf('.');
    if (dot != -1 && number.length - dot - 1 >= decimalDigits) return this;
    // Keep each number to 12 whole digits: a guard against runaway input.
    if (dot == -1 && number.length >= 12) return this;
    if (number == '0' && d != '.') {
      return AmountExpression(text.substring(0, text.length - 1) + d);
    }
    return AmountExpression(text + d);
  }

  AmountExpression decimalPoint({required int decimalDigits}) {
    if (decimalDigits == 0 || _lastNumber.contains('.')) return this;
    return AmountExpression('$text${_lastNumber.isEmpty ? '0' : ''}.');
  }

  AmountExpression operator(String op) {
    if (text.isEmpty) return this;
    final last = text[text.length - 1];
    if (operators.contains(last)) {
      return AmountExpression(text.substring(0, text.length - 1) + op);
    }
    return AmountExpression(text + op);
  }

  /// Turns the number being typed into a percentage (200 → 2).
  AmountExpression percent({required int decimalDigits}) {
    final number = _lastNumber;
    if (number.isEmpty) return this;
    final minor = _toMinor(number, decimalDigits);
    final head = text.substring(0, text.length - number.length);
    return AmountExpression(head + plain((minor / 100).round(), decimalDigits));
  }

  /// "=": collapses the expression into its result, ready to keep typing.
  AmountExpression resolve({required int decimalDigits}) {
    if (!hasOperator) return this;
    final result = evaluate(decimalDigits: decimalDigits);
    return AmountExpression(result == 0 ? '' : plain(result, decimalDigits));
  }

  /// Minor units as plain calculator text: "150" or "150.5", never grouped.
  static String plain(int minor, int decimalDigits) {
    final unit = math.pow(10, decimalDigits).toInt();
    final fraction = minor % unit;
    if (fraction == 0) return '${minor ~/ unit}';
    final f = fraction
        .toString()
        .padLeft(decimalDigits, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${minor ~/ unit}.$f';
  }

  AmountExpression backspace() => text.isEmpty
      ? this
      : AmountExpression(text.substring(0, text.length - 1));

  /// The value in minor units. Negative and incomplete results count as 0,
  /// and division rounds half up.
  int evaluate({required int decimalDigits}) {
    if (text.isEmpty) return 0;
    final unit = math.pow(10, decimalDigits).toInt();
    final tokens = RegExp(r'[+−×÷]|[0-9.]+').allMatches(text).map((m) => m[0]!);

    // Operands are scaled to minor units; × and ÷ fold into the current
    // term right away, and + and − combine terms at the end.
    final terms = <int>[];
    final signs = <int>[1];
    int? current;
    String? pendingMul;
    for (final token in tokens) {
      if (token == '+' || token == '−') {
        if (current != null) terms.add(current);
        current = null;
        pendingMul = null;
        signs.add(token == '+' ? 1 : -1);
      } else if (token == '×' || token == '÷') {
        pendingMul = token;
      } else {
        final value = _toMinor(token, decimalDigits);
        if (current == null || pendingMul == null) {
          current = value;
        } else if (pendingMul == '×') {
          current = (current * value / unit).round();
        } else {
          current = value == 0 ? 0 : (current * unit / value).round();
        }
        pendingMul = null;
      }
    }
    if (current != null) terms.add(current);

    var total = 0;
    for (var i = 0; i < terms.length; i++) {
      total += terms[i] * signs[i];
    }
    return math.max(total, 0);
  }

  static int _toMinor(String number, int decimalDigits) {
    final parts = number.split('.');
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
    var fraction = parts.length > 1 ? parts[1] : '';
    fraction = fraction
        .padRight(decimalDigits, '0')
        .substring(0, decimalDigits);
    return whole * math.pow(10, decimalDigits).toInt() +
        (fraction.isEmpty ? 0 : int.parse(fraction));
  }
}
