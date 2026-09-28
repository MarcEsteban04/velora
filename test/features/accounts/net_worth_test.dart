import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/core/utils/percentages.dart';

Account _a(
  String id,
  AccountType type,
  String currency,
  int minor, {
  bool include = true,
}) => Account(
  id: id,
  name: id,
  type: type,
  currencyCode: currency,
  openingBalanceMinor: minor,
  includeInNetWorth: include,
  createdAt: DateTime(2026),
);

void main() {
  test('sums the main currency, splits by type, keeps others separate', () {
    final worth = NetWorth.of([
      _a('cash', AccountType.cash, 'PHP', 1200000),
      _a('bank', AccountType.bank, 'PHP', 800000),
      _a('bank2', AccountType.bank, 'PHP', 200000),
      _a('usd', AccountType.bank, 'USD', 50000),
    ], 'PHP');

    expect(worth.totalMinor, 2200000);
    expect(worth.byType[AccountType.bank], 1000000);
    expect(worth.byType[AccountType.cash], 1200000);
    expect(worth.otherCurrencies, {'USD': 50000});
  });

  test('accounts excluded from net worth are not counted anywhere', () {
    final worth = NetWorth.of([
      _a('mine', AccountType.cash, 'PHP', 1000),
      _a('shared', AccountType.eWallet, 'PHP', 9000, include: false),
    ], 'PHP');

    expect(worth.totalMinor, 1000);
    expect(worth.byType.containsKey(AccountType.eWallet), isFalse);
  });

  test('allocation percentages always add up to 100', () {
    // Plain rounding gives 98 + 2 + 1 = 101 here.
    final p = percentagesSummingTo100([125000000, 1950000, 1200000]);
    expect(p.reduce((a, b) => a + b), 100);
    // 97.54 / 1.52 / 0.94: the two largest remainders round up.
    expect(p, [98, 1, 1]);
    expect(percentagesSummingTo100([1, 1, 1]).reduce((a, b) => a + b), 100);
  });
}
