import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/money/exchange_rates.dart';
import 'package:velora/features/payoneer/domain/payoneer_activity.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

void main() {
  final rate = ExchangeRate(
    from: 'USD',
    to: 'PHP',
    rate: 62.5,
    asOf: DateTime(2026, 9, 28),
    source: 'European Central Bank',
  );

  test('converts minor units, less a spread', () {
    expect(rate.convert(50000), 3125000); // $500 → ₱31,250
    expect(rate.convert(50000, spread: 0.02), 3062500); // → ₱30,625
    // Zero-decimal currencies keep their own scale.
    final jpy = ExchangeRate(
      from: 'USD',
      to: 'JPY',
      rate: 150,
      asOf: DateTime(2026),
      source: 'x',
    );
    expect(jpy.convert(1000), 1500); // $10 → ¥1,500
  });

  test('round-trips through JSON for the offline cache', () {
    final back = ExchangeRate.fromJson(rate.toJson())!;
    expect(back.rate, 62.5);
    expect(back.asOf, DateTime(2026, 9, 28));
    expect(ExchangeRate.fromJson('nonsense'), isNull);
  });

  test('a year of salary: received, withdrawn and the average rate', () {
    Transaction tx(
      String id,
      TransactionKind kind,
      int amount, {
      String? to,
      int? toAmount,
      DateTime? at,
    }) => Transaction(
      id: id,
      kind: kind,
      amountMinor: amount,
      accountId: 'payo',
      toAccountId: to,
      toAmountMinor: toAmount,
      occurredAt: at ?? DateTime(2026, 6),
    );
    final activity = PayoneerActivity.of(
      'payo',
      [
        tx('a', TransactionKind.income, 200000),
        tx(
          'b',
          TransactionKind.transfer,
          100000,
          to: 'mari',
          toAmount: 6100000,
        ),
        tx('c', TransactionKind.transfer, 50000, to: 'bpi', toAmount: 3100000),
        // Last year: listed, not counted.
        tx('d', TransactionKind.income, 99900, at: DateTime(2025, 12)),
      ],
      currencyOf: (id) => Currencies.byCode(id == 'payo' ? 'USD' : 'PHP'),
      since: DateTime(2026),
    );
    expect(activity.receivedMinor, 200000);
    expect(activity.received, hasLength(2));
    expect(activity.withdrawnMinor, 150000);
    expect(activity.withdrawnToMinor['PHP'], 9200000);
    expect(activity.withdrawals.first.rate, closeTo(61.0, 1e-9));
    expect(
      activity.averageRate(Currencies.byCode('USD'), Currencies.byCode('PHP')),
      closeTo(61.3333, 1e-3),
    );
  });
}
