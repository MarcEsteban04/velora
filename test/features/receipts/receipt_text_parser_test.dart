import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/receipts/domain/receipt_text_parser.dart';

final _now = DateTime(2026, 9, 30, 12);

void main() {
  test('a fast food receipt', () {
    final r = ReceiptTextParser.parse('''
JOLLIBEE
SM MEGAMALL
VAT REG TIN 000-123-456-000
OFFICIAL RECEIPT
09/28/2026 12:41 PM
1 Chickenjoy 1pc        99.00
1 Jolly Spaghetti       65.00
2 Coke Regular          90.00
SUBTOTAL               254.00
VATABLE SALES          226.79
VAT 12%                 27.21
TOTAL                  254.00
CASH                   500.00
CHANGE                 246.00
THANK YOU!
''', now: _now)!;
    expect(r.totalMinor, 25400);
    expect(r.merchant, 'Jollibee');
    expect(r.date, DateTime(2026, 9, 28));
    expect(r.items.map((i) => i.name), [
      'Chickenjoy 1pc',
      'Jolly Spaghetti',
      'Coke Regular',
    ]);
  });

  test('the amount on the next line, with a peso sign and commas', () {
    final r = ReceiptTextParser.parse('''
Puregold Price Club
Sep 27, 2026
Rice 5kg  ₱ 310.00
AMOUNT DUE
₱1,245.50
''', now: _now)!;
    expect(r.totalMinor, 124550);
    expect(r.merchant, 'Puregold Price Club');
    expect(r.date, DateTime(2026, 9, 27));
  });

  test('without a total label, the biggest amount that is not cash', () {
    final r = ReceiptTextParser.parse('''
Kape Tayo
Latte 150.00
Croissant 95.00
245.00
Cash 300.00
''', now: _now)!;
    expect(r.totalMinor, 24500);
  });

  test('no amounts means no receipt', () {
    expect(ReceiptTextParser.parse('hello world', now: _now), isNull);
    expect(ReceiptTextParser.parse('', now: _now), isNull);
  });
}
