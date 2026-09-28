import 'dart:ui';

import 'package:intl/intl.dart';

/// A currency Velora supports. Symbols and decimal places come from `intl`,
/// so they match each currency's conventions (for example ¥ has no decimals).
class Currency {
  const Currency(this.code, this.name);

  /// ISO 4217 code, for example `PHP`.
  final String code;
  final String name;

  NumberFormat get _format => NumberFormat.simpleCurrency(name: code);

  String get symbol => _format.currencySymbol;
  int get decimalDigits => _format.decimalDigits ?? 2;

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

abstract final class Currencies {
  static const all = [
    Currency('PHP', 'Philippine Peso'),
    Currency('USD', 'US Dollar'),
    Currency('EUR', 'Euro'),
    Currency('GBP', 'British Pound'),
    Currency('JPY', 'Japanese Yen'),
    Currency('AUD', 'Australian Dollar'),
    Currency('CAD', 'Canadian Dollar'),
    Currency('SGD', 'Singapore Dollar'),
    Currency('HKD', 'Hong Kong Dollar'),
    Currency('TWD', 'New Taiwan Dollar'),
    Currency('CNY', 'Chinese Yuan'),
    Currency('KRW', 'South Korean Won'),
    Currency('INR', 'Indian Rupee'),
    Currency('IDR', 'Indonesian Rupiah'),
    Currency('MYR', 'Malaysian Ringgit'),
    Currency('THB', 'Thai Baht'),
    Currency('VND', 'Vietnamese Dong'),
    Currency('AED', 'UAE Dirham'),
    Currency('SAR', 'Saudi Riyal'),
    Currency('CHF', 'Swiss Franc'),
    Currency('NZD', 'New Zealand Dollar'),
    Currency('MXN', 'Mexican Peso'),
    Currency('BRL', 'Brazilian Real'),
    Currency('ZAR', 'South African Rand'),
  ];

  static const fallback = Currency('USD', 'US Dollar');

  static Currency byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => fallback);

  /// The currency for the device's region, when Velora supports it.
  static Currency fromDeviceLocale([Locale? locale]) {
    try {
      final tag = (locale ?? PlatformDispatcher.instance.locale).toString();
      final code = NumberFormat.simpleCurrency(
        locale: Intl.canonicalizedLocale(tag),
      ).currencyName;
      return code == null ? fallback : byCode(code);
    } catch (_) {
      return fallback;
    }
  }

  /// The quick-pick grid: the device currency first, then the most common
  /// ones, with no duplicates.
  static List<Currency> popular(Currency device) {
    const common = ['USD', 'EUR', 'GBP', 'JPY', 'PHP', 'AUD', 'SGD'];
    return {device, ...common.map(byCode)}.take(6).toList();
  }
}
