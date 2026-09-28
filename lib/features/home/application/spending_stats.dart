import '../../transactions/domain/transaction.dart';

/// Spending per day for the last [days] days, oldest first, today last.
/// Only expenses from accounts in the main currency count.
List<(DateTime day, int spentMinor)> dailySpending(
  List<Transaction> transactions, {
  required DateTime now,
  required bool Function(String accountId) inMainCurrency,
  int days = 7,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final totals = <DateTime, int>{};
  for (final t in transactions) {
    if (t.kind != TransactionKind.expense || !inMainCurrency(t.accountId)) {
      continue;
    }
    final l = t.occurredAt;
    final d = DateTime(l.year, l.month, l.day);
    totals.update(d, (v) => v + t.amountMinor, ifAbsent: () => t.amountMinor);
  }
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (d, totals[d] ?? 0);
      }(),
  ];
}

enum SpendPeriod {
  day('Day', 'Today', 'yesterday'),
  week('Week', 'This week', 'last week'),
  month('Month', 'This month', 'last month');

  const SpendPeriod(this.label, this.title, this.previous);
  final String label;

  /// "Today", "This week"...
  final String title;

  /// "yesterday", "last week"... as in "12% less than last week".
  final String previous;
}

/// Spending so far in a period, next to the same stretch of the previous
/// one: today vs yesterday, Monday-to-now vs the same days last week, the
/// 1st-to-today vs the same days last month. Comparing like with like keeps
/// "you're spending less" honest early in a period.
class PeriodSpend {
  const PeriodSpend({required this.currentMinor, required this.previousMinor});

  final int currentMinor;
  final int previousMinor;

  /// The change against the previous stretch, as a fraction (0.12 = 12%
  /// more). Null when there's nothing to compare against.
  double? get change => previousMinor == 0
      ? null
      : (currentMinor - previousMinor) / previousMinor;

  factory PeriodSpend.of(
    SpendPeriod period,
    List<Transaction> transactions, {
    required DateTime now,
    required bool Function(String accountId) inMainCurrency,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final (
      DateTime start,
      DateTime prevStart,
      DateTime prevEnd,
    ) = switch (period) {
      SpendPeriod.day => (
        today,
        DateTime(now.year, now.month, now.day - 1),
        today,
      ),
      SpendPeriod.week => () {
        final monday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        return (
          monday,
          DateTime(monday.year, monday.month, monday.day - 7),
          DateTime(now.year, now.month, now.day - 6),
        );
      }(),
      SpendPeriod.month => () {
        final first = DateTime(now.year, now.month);
        final prevFirst = DateTime(now.year, now.month - 1);
        // The same number of days into last month, capped at its end.
        final prevMonthDays = DateTime(now.year, now.month, 0).day;
        final day = now.day > prevMonthDays ? prevMonthDays : now.day;
        return (
          first,
          prevFirst,
          DateTime(prevFirst.year, prevFirst.month, day + 1),
        );
      }(),
    };

    int sum(DateTime from, DateTime to) {
      var total = 0;
      for (final t in transactions) {
        if (t.kind != TransactionKind.expense || !inMainCurrency(t.accountId)) {
          continue;
        }
        final at = t.occurredAt;
        if (!at.isBefore(from) && at.isBefore(to)) total += t.amountMinor;
      }
      return total;
    }

    return PeriodSpend(
      currentMinor: sum(start, tomorrow),
      previousMinor: sum(prevStart, prevEnd),
    );
  }
}
