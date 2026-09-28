import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/money/money.dart';

void main() {
  final php = Currencies.byCode('PHP');
  final jpy = Currencies.byCode('JPY');

  group('Money.parseMinor', () {
    test('parses grouped amounts with decimals into minor units', () {
      expect(Money.parseMinor('12,000.5', php), 1200050);
      expect(Money.parseMinor('0.07', php), 7);
      expect(Money.parseMinor('', php), 0);
    });

    test('respects zero-decimal currencies', () {
      expect(jpy.decimalDigits, 0);
      expect(Money.parseMinor('1,500', jpy), 1500);
    });
  });

  test('format and toInputText round-trip', () {
    expect(Money.format(1200000, php), '₱12,000.00');
    expect(Money.toInputText(1200050, php), '12,000.5');
    expect(Money.toInputText(1200000, php), '12,000');
    expect(Money.parseMinor(Money.toInputText(987654, php), php), 987654);
  });

  group('MoneyInputFormatter', () {
    String type(MoneyInputFormatter f, String input) => f
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input))
        .text;

    test('groups thousands and trims leading zeros', () {
      final f = MoneyInputFormatter(2);
      expect(type(f, '12000'), '12,000');
      expect(type(f, '0012'), '12');
      expect(type(f, '.5'), '0.5');
    });

    test('caps decimals to the currency', () {
      expect(type(MoneyInputFormatter(2), '1.234'), '1.23');
      expect(type(MoneyInputFormatter(0), '1.5'), '15');
    });
  });

  test('popular currencies lead with the device currency, no duplicates', () {
    final list = Currencies.popular(php);
    expect(list.first, php);
    expect(list.toSet().length, list.length);
    expect(list.length, 6);
  });
}
