import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/transactions/application/amount_expression.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

AmountExpression type(String keys, {int digits = 2}) {
  var e = const AmountExpression();
  for (final k in keys.split('')) {
    if (k == '.') {
      e = e.decimalPoint(decimalDigits: digits);
    } else if (AmountExpression.operators.contains(k)) {
      e = e.operator(k);
    } else {
      e = e.digit(k, decimalDigits: digits);
    }
  }
  return e;
}

void main() {
  group('AmountExpression', () {
    test('plain amounts become minor units', () {
      expect(type('150').evaluate(decimalDigits: 2), 15000);
      expect(type('12.5').evaluate(decimalDigits: 2), 1250);
      expect(type('.5').text, '0.5');
    });

    test('× and ÷ bind tighter than + and −', () {
      expect(type('150+45').evaluate(decimalDigits: 2), 19500);
      expect(type('100+20×3').evaluate(decimalDigits: 2), 16000);
      expect(type('90÷3−10').evaluate(decimalDigits: 2), 2000);
    });

    test('decimals are capped to the currency', () {
      expect(type('1.239').text, '1.23');
      expect(type('1.5', digits: 0).text, '15');
      expect(type('1500', digits: 0).evaluate(decimalDigits: 0), 1500);
    });

    test('a repeated operator replaces the previous one', () {
      expect(type('5+×2').text, '5×2');
      expect(type('+5').text, '5');
    });

    test('leading zeros are replaced, not stacked', () {
      expect(type('007').text, '7');
    });

    test('% turns the current number into a percentage', () {
      expect(
        type('200').percent(decimalDigits: 2).evaluate(decimalDigits: 2),
        200,
      );
      expect(type('50+10').percent(decimalDigits: 2).text, '50+0.1');
    });

    test('= collapses the expression to its result', () {
      expect(type('150+45').resolve(decimalDigits: 2).text, '195');
      expect(type('10÷4').resolve(decimalDigits: 2).text, '2.5');
    });

    test('negative results and division by zero are safe', () {
      expect(type('5−10').evaluate(decimalDigits: 2), 0);
      expect(type('5÷0').evaluate(decimalDigits: 2), 0);
      expect(type('150+').evaluate(decimalDigits: 2), 15000);
    });
  });

  test('transfers are neither income nor spending', () {
    final at = DateTime(2026, 9, 28);
    Transaction t(TransactionKind kind, int minor) => Transaction(
      id: '$kind$minor',
      kind: kind,
      amountMinor: minor,
      accountId: 'a',
      toAccountId: kind == TransactionKind.transfer ? 'b' : null,
      occurredAt: at,
    );
    final flow = FlowSummary.of([
      t(TransactionKind.income, 500000),
      t(TransactionKind.expense, 15000),
      t(TransactionKind.transfer, 100000),
    ], inCurrency: (_) => true);

    expect(flow.incomeMinor, 500000);
    expect(flow.spentMinor, 15000);
    expect(flow.netMinor, 485000);
  });
}
