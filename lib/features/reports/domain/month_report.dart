import 'dart:math' as math;

import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// One category's slice of a month's spending.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amountMinor,
    required this.share,
    required this.count,
  });

  /// Null for the "Other" row that folds the tail together.
  final Category? category;
  final int amountMinor;

  /// 0 to 1 of the month's spending.
  final double share;
  final int count;
}

/// A month, summed up: in, out, what was kept, where it went, how the
/// spending built up day by day, and the biggest expenses. Main currency
/// only, and transfers never count.
class MonthReport {
  MonthReport._({
    required this.month,
    required this.days,
    required this.daysCounted,
    required this.incomeMinor,
    required this.spentMinor,
    required this.byCategory,
    required this.cumulative,
    required this.biggest,
    required this.expenseCount,
  });

  /// [transactions] are the month's (any order); [inMain] keeps the main
  /// currency's. [now] decides how far into the current month to count.
  factory MonthReport.of(
    DateTime month,
    Iterable<Transaction> transactions, {
    required Map<String, Category> categories,
    required bool Function(String accountId) inMain,
    required DateTime now,
    int topCategories = 6,
  }) {
    final start = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final isCurrent = now.year == month.year && now.month == month.month;
    final isFuture = start.isAfter(now);
    final counted = isFuture ? 0 : (isCurrent ? now.day : days);

    final mine = transactions.where(
      (t) =>
          inMain(t.accountId) &&
          t.kind != TransactionKind.transfer &&
          t.occurredAt.year == month.year &&
          t.occurredAt.month == month.month,
    );
    var income = 0, spent = 0;
    final perDay = List.filled(days, 0);
    final perCategory = <String?, (int, int)>{};
    final expenses = <Transaction>[];
    for (final t in mine) {
      if (t.kind == TransactionKind.income) {
        income += t.amountMinor;
        continue;
      }
      spent += t.amountMinor;
      expenses.add(t);
      perDay[t.occurredAt.day - 1] += t.amountMinor;
      final key = categories.containsKey(t.categoryId) ? t.categoryId : null;
      final (sum, n) = perCategory[key] ?? (0, 0);
      perCategory[key] = (sum + t.amountMinor, n + 1);
    }

    // Biggest first; the tail past [topCategories] folds into Other, along
    // with spending that has no (known) category.
    final ranked = perCategory.entries.where((e) => e.key != null).toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final top = ranked.take(topCategories).toList();
    var otherSum = perCategory[null]?.$1 ?? 0;
    var otherCount = perCategory[null]?.$2 ?? 0;
    for (final e in ranked.skip(topCategories)) {
      otherSum += e.value.$1;
      otherCount += e.value.$2;
    }
    double share(int v) => spent == 0 ? 0 : v / spent;
    final byCategory = [
      for (final e in top)
        CategorySpend(
          category: categories[e.key],
          amountMinor: e.value.$1,
          share: share(e.value.$1),
          count: e.value.$2,
        ),
      if (otherSum > 0)
        CategorySpend(
          category: null,
          amountMinor: otherSum,
          share: share(otherSum),
          count: otherCount,
        ),
    ];

    // Running total, only through the days that have happened.
    final cumulative = <int>[];
    var running = 0;
    for (var d = 0; d < counted; d++) {
      running += perDay[d];
      cumulative.add(running);
    }

    expenses.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return MonthReport._(
      month: start,
      days: days,
      daysCounted: counted,
      incomeMinor: income,
      spentMinor: spent,
      byCategory: byCategory,
      cumulative: cumulative,
      biggest: expenses.take(5).toList(),
      expenseCount: expenses.length,
    );
  }

  final DateTime month;

  /// Days in the month.
  final int days;

  /// Days so far (all of them for a past month).
  final int daysCounted;
  final int incomeMinor;
  final int spentMinor;
  final List<CategorySpend> byCategory;

  /// Spending so far at the end of each day counted, day 1 first.
  final List<int> cumulative;

  /// The five biggest expenses, biggest first.
  final List<Transaction> biggest;
  final int expenseCount;

  int get keptMinor => incomeMinor - spentMinor;

  /// Share of income kept, when there was income.
  double? get savingsRate => incomeMinor == 0 ? null : keptMinor / incomeMinor;

  int get dailyAverageMinor =>
      daysCounted == 0 ? 0 : (spentMinor / daysCounted).round();

  bool get isEmpty => incomeMinor == 0 && spentMinor == 0;

  /// What was spent by day [day] (1-based), clamped to the days counted.
  int spentByDay(int day) {
    if (cumulative.isEmpty || day < 1) return 0;
    return cumulative[math.min(day, cumulative.length) - 1];
  }
}

/// A change against the month before: +12% means spent 12% more.
double? changeOf(int now, int before) =>
    before == 0 ? null : (now - before) / before;

/// In and out for one month, for the six-month trend.
class MonthFlow {
  const MonthFlow({
    required this.month,
    required this.incomeMinor,
    required this.spentMinor,
  });

  final DateTime month;
  final int incomeMinor;
  final int spentMinor;
}
