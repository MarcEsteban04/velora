import '../../transactions/domain/transaction.dart';

/// How often a budget resets.
enum BudgetPeriod {
  daily('Daily', 'day', 'today'),
  weekly('Weekly', 'week', 'this week'),
  monthly('Monthly', 'month', 'this month'),
  yearly('Yearly', 'year', 'this year');

  const BudgetPeriod(this.label, this.unit, this.current);
  final String label;

  /// "day", "week"... as in "₱5,000 a month".
  final String unit;

  /// "this week"... as in "₱1,200 left this week".
  final String current;

  /// The period containing [now]: [start, end) in local time. Weeks start
  /// on Monday.
  (DateTime, DateTime) range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      daily => (today, DateTime(now.year, now.month, now.day + 1)),
      weekly => () {
        final start = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        return (start, DateTime(start.year, start.month, start.day + 7));
      }(),
      monthly => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
      yearly => (DateTime(now.year), DateTime(now.year + 1)),
    };
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amountMinor,
    required this.period,
  });

  final String id;
  final String categoryId;

  /// The limit per period, in the main currency's minor units.
  final int amountMinor;
  final BudgetPeriod period;

  factory Budget.fromRow(Map<String, dynamic> row) => Budget(
    id: row['id'] as String,
    categoryId: row['category_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    period:
        BudgetPeriod.values.asNameMap()[row['period'] as String] ??
        BudgetPeriod.monthly,
  );
}

class BudgetDraft {
  const BudgetDraft({
    required this.categoryId,
    required this.amountMinor,
    required this.period,
  });

  final String categoryId;
  final int amountMinor;
  final BudgetPeriod period;

  Map<String, Object> toRow() => {
    'category_id': categoryId,
    'amount_minor': amountMinor,
    'period': period.name,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

enum BudgetPace {
  /// Spending is at or below where it should be by now.
  onTrack,

  /// Spending faster than the period is passing.
  fast,

  /// Nearly all of it is used (85% or more), though not over.
  nearLimit,

  /// Over the limit.
  over,
}

/// Where a budget stands right now.
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spentMinor,
    required this.start,
    required this.end,
    required this.elapsed,
    required this.daysLeft,
  });

  final Budget budget;
  final int spentMinor;
  final DateTime start;
  final DateTime end;

  /// How much of the period has passed, 0 to 1.
  final double elapsed;

  /// Days left, today included.
  final int daysLeft;

  int get limitMinor => budget.amountMinor;
  int get remainingMinor => limitMinor - spentMinor;
  double get used => spentMinor / limitMinor;

  /// What could still be spent each day, today included, to finish on
  /// budget. Zero once over.
  int get dailyAllowanceMinor =>
      remainingMinor <= 0 ? 0 : remainingMinor ~/ (daysLeft < 1 ? 1 : daysLeft);

  BudgetPace get pace {
    if (spentMinor > limitMinor) return BudgetPace.over;
    if (used >= 0.85) return BudgetPace.nearLimit;
    // Early in a period a single purchase looks "fast"; ignore small spends.
    if (used >= 0.2 && used > elapsed * 1.1) return BudgetPace.fast;
    return BudgetPace.onTrack;
  }

  /// Spending by the end of the period if it carries on at this pace. Null
  /// when it's too early to tell, or for daily budgets.
  int? get projectedMinor {
    if (budget.period == BudgetPeriod.daily || elapsed < 0.2) return null;
    return (spentMinor / elapsed).round();
  }

  /// Works out a budget's status from transactions. [inMainCurrency] picks
  /// the accounts whose spending counts.
  factory BudgetStatus.of(
    Budget budget,
    List<Transaction> transactions, {
    required DateTime now,
    required bool Function(String accountId) inMainCurrency,
  }) {
    final (start, end) = budget.period.range(now);
    var spent = 0;
    for (final t in transactions) {
      final at = t.occurredAt;
      if (t.kind == TransactionKind.expense &&
          t.categoryId == budget.categoryId &&
          inMainCurrency(t.accountId) &&
          !at.isBefore(start) &&
          at.isBefore(end)) {
        spent += t.amountMinor;
      }
    }
    final total = end.difference(start).inSeconds;
    final passed = now.difference(start).inSeconds;
    final today = DateTime(now.year, now.month, now.day);
    return BudgetStatus(
      budget: budget,
      spentMinor: spent,
      start: start,
      end: end,
      elapsed: (passed / total).clamp(0.0, 1.0),
      daysLeft: end.difference(today).inDays,
    );
  }
}

/// A limit to suggest for a category: last month's spending rounded up to a
/// friendly number. Null when there's nothing to go on.
int? suggestedBudgetMinor(int lastMonthMinor, {required int minorPerUnit}) {
  if (lastMonthMinor <= 0) return null;
  final units = lastMonthMinor / minorPerUnit;
  // Steps that stay within about 10% of what was actually spent.
  final step = units >= 20000
      ? 1000
      : units >= 5000
      ? 500
      : units >= 1000
      ? 100
      : units >= 100
      ? 10
      : 5;
  return ((units / step).ceil() * step * minorPerUnit).round();
}
