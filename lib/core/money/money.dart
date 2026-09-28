import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'currency.dart';

/// Money is stored as an integer count of the currency's minor unit (cents,
/// centavos...). That avoids floating-point rounding errors in totals.
abstract final class Money {
  static String format(int minor, Currency currency) {
    final digits = currency.decimalDigits;
    return NumberFormat.currency(
      name: currency.code,
      symbol: currency.symbol,
      decimalDigits: digits,
    ).format(minor / math.pow(10, digits));
  }

  /// Parses user input such as `12,000.5` into minor units. It works on the
  /// string directly, never through a double, so no precision is lost.
  static int parseMinor(String input, Currency currency) {
    final digits = currency.decimalDigits;
    final clean = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (clean.isEmpty || clean == '.') return 0;
    final parts = clean.split('.');
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
    var fraction = parts.length > 1 ? parts[1] : '';
    fraction = fraction.padRight(digits, '0').substring(0, digits);
    return whole * math.pow(10, digits).toInt() +
        (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  /// The inverse of [parseMinor], for pre-filling an amount field: grouped,
  /// without a symbol, and with decimals shown only when they're non-zero.
  static String toInputText(int minor, Currency currency) {
    if (minor == 0) return '';
    final digits = currency.decimalDigits;
    final unit = math.pow(10, digits).toInt();
    final whole = NumberFormat('#,##0', 'en_US').format(minor ~/ unit);
    final fraction = minor % unit;
    if (fraction == 0) return whole;
    final padded = fraction.toString().padLeft(digits, '0');
    return '$whole.${padded.replaceFirst(RegExp(r'0+$'), '')}';
  }
}

/// Formats an amount field as the user types. It adds thousands separators
/// and limits the number of decimals to what the currency allows.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.decimalDigits);

  final int decimalDigits;
  static final _grouping = NumberFormat('#,##0', 'en_US');
  static const _maxWholeDigits = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (decimalDigits == 0) raw = raw.replaceAll('.', '');

    final dot = raw.indexOf('.');
    var whole = dot == -1 ? raw : raw.substring(0, dot);
    var fraction = dot == -1
        ? null
        : raw.substring(dot + 1).replaceAll('.', '');

    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > _maxWholeDigits) return oldValue;
    if (fraction != null && fraction.length > decimalDigits) {
      fraction = fraction.substring(0, decimalDigits);
    }

    final grouped = whole.isEmpty
        ? (fraction != null ? '0' : '')
        : _grouping.format(int.parse(whole));
    final text = fraction == null ? grouped : '$grouped.$fraction';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
