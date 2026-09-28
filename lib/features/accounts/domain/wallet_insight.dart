import '../../transactions/domain/transaction.dart';
import 'account.dart';

/// Net worth at the end of each of the last few days, oldest first.
///
/// It works backwards from today's live balances: the end of yesterday is
/// today's total minus whatever happened today, and so on. Only accounts
/// that count toward net worth, in the main currency, are included, the
/// same rule as the net worth figure.
List<(DateTime day, int totalMinor)> dailyBalances({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required String mainCurrency,
  required DateTime now,
  int days = 7,
}) {
  final counted = {
    for (final a in accounts)
      if (a.includeInNetWorth && a.currencyCode == mainCurrency) a.id,
  };
  var total = accounts
      .where((a) => counted.contains(a.id))
      .fold<int>(0, (s, a) => s + a.balanceMinor);

  int changeOn(DateTime day) {
    var change = 0;
    for (final t in transactions) {
      final d = DateTime(
        t.occurredAt.year,
        t.occurredAt.month,
        t.occurredAt.day,
      );
      if (d != day) continue;
      final fromCounted = counted.contains(t.accountId);
      switch (t.kind) {
        case TransactionKind.income:
          if (fromCounted) change += t.amountMinor;
        case TransactionKind.expense:
          if (fromCounted) change -= t.amountMinor;
        case TransactionKind.transfer:
          if (fromCounted) change -= t.amountMinor;
          if (counted.contains(t.toAccountId)) {
            change += t.toAmountMinor ?? t.amountMinor;
          }
      }
    }
    return change;
  }

  final today = DateTime(now.year, now.month, now.day);
  final result = <(DateTime, int)>[];
  for (var i = 0; i < days; i++) {
    final day = today.subtract(Duration(days: i));
    result.add((day, total));
    total -= changeOn(day);
  }
  return result.reversed.toList();
}

/// The few numbers an insight is based on. Only these (never notes or
/// account names) leave the phone when asking the AI for an insight.
class WalletSnapshot {
  const WalletSnapshot({
    required this.currencyCode,
    required this.netWorthMinor,
    required this.accountCount,
    required this.allocationPercent,
    required this.weekChangeMinor,
    required this.monthIncomeMinor,
    required this.monthSpentMinor,
    required this.dayOfMonth,
    this.topCategory,
  });

  final String currencyCode;
  final int netWorthMinor;
  final int accountCount;

  /// Account type name to its whole-number share of net worth.
  final Map<String, int> allocationPercent;
  final int weekChangeMinor;
  final int monthIncomeMinor;
  final int monthSpentMinor;

  /// How far into the month we are, so spending can be read in context.
  final int dayOfMonth;
  final String? topCategory;

  /// Months the current net worth would last at this month's spending pace.
  /// Null until there's spending to measure.
  double? get runwayMonths {
    if (monthSpentMinor <= 0 || dayOfMonth <= 0) return null;
    final monthlyPace = monthSpentMinor * 30 / dayOfMonth;
    return netWorthMinor / monthlyPace;
  }

  Map<String, Object?> toJson() => {
    'currency': currencyCode,
    'net_worth_minor': netWorthMinor,
    'account_count': accountCount,
    'allocation_percent': allocationPercent,
    'week_change_minor': weekChangeMinor,
    'month_income_minor': monthIncomeMinor,
    'month_spent_minor': monthSpentMinor,
    'day_of_month': dayOfMonth,
    'top_category': topCategory,
  };

  /// Coarse enough that small changes reuse today's cached insight, fine
  /// enough that real changes get a fresh one.
  String get cacheKey => [
    currencyCode,
    netWorthMinor ~/ 100000,
    monthSpentMinor ~/ 50000,
    monthIncomeMinor ~/ 50000,
    accountCount,
    topCategory,
  ].join('|');
}
