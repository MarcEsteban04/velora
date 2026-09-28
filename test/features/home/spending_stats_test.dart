import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/home/application/spending_stats.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

final _now = DateTime(2026, 9, 30, 18); // A Wednesday.

Transaction _t(
  DateTime at,
  int minor, {
  TransactionKind kind = TransactionKind.expense,
  String account = 'php',
}) => Transaction(
  id: '$at-$minor-$kind',
  kind: kind,
  amountMinor: minor,
  accountId: account,
  occurredAt: at,
);

bool _php(String id) => id == 'php';

void main() {
  test('daily spending covers 7 days, today last, expenses only', () {
    final days = dailySpending(
      [
        _t(DateTime(2026, 9, 30, 9), 100),
        _t(DateTime(2026, 9, 30, 10), 50),
        _t(DateTime(2026, 9, 28), 70),
        _t(DateTime(2026, 9, 28), 999, kind: TransactionKind.income),
        _t(DateTime(2026, 9, 27), 999, account: 'usd'),
        _t(DateTime(2026, 9, 20), 999),
      ],
      now: _now,
      inMainCurrency: _php,
    );

    expect(days, hasLength(7));
    expect(days.first.$1, DateTime(2026, 9, 24));
    expect(days.last, (DateTime(2026, 9, 30), 150));
    expect(days[4], (DateTime(2026, 9, 28), 70));
    expect(days[3].$2, 0);
  });

  group('period spending compares like with like', () {
    test('today against yesterday', () {
      final s = PeriodSpend.of(
        SpendPeriod.day,
        [_t(DateTime(2026, 9, 30, 8), 300), _t(DateTime(2026, 9, 29, 20), 400)],
        now: _now,
        inMainCurrency: _php,
      );
      expect(s.currentMinor, 300);
      expect(s.previousMinor, 400);
      expect(s.change, closeTo(-0.25, 1e-9));
    });

    test('Monday to now against the same days last week', () {
      final s = PeriodSpend.of(
        SpendPeriod.week,
        [
          _t(DateTime(2026, 9, 28), 100), // this Monday
          _t(DateTime(2026, 9, 30), 100), // today
          _t(DateTime(2026, 9, 21), 50), // last Monday
          _t(DateTime(2026, 9, 23, 20), 50), // last Wednesday
          _t(DateTime(2026, 9, 24), 999), // last Thursday: not yet comparable
        ],
        now: _now,
        inMainCurrency: _php,
      );
      expect(s.currentMinor, 200);
      expect(s.previousMinor, 100);
      expect(s.change, closeTo(1, 1e-9));
    });

    test('this month so far against the same days last month', () {
      final s = PeriodSpend.of(
        SpendPeriod.month,
        [
          _t(DateTime(2026, 9, 5), 500),
          _t(DateTime(2026, 8, 30), 200),
          _t(DateTime(2026, 8, 31), 999), // past the 30th
        ],
        now: _now,
        inMainCurrency: _php,
      );
      expect(s.currentMinor, 500);
      expect(s.previousMinor, 200);
    });

    test('nothing to compare against', () {
      final s = PeriodSpend.of(
        SpendPeriod.day,
        [_t(DateTime(2026, 9, 30, 8), 300)],
        now: _now,
        inMainCurrency: _php,
      );
      expect(s.change, isNull);
    });
  });
}
