import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/budgets/domain/budget.dart';
import 'package:velora/features/goals/domain/goal.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

Transaction _spend(
  DateTime at,
  int minor, {
  String cat = 'food',
  String acc = 'php',
}) => Transaction(
  id: '$at-$minor',
  kind: TransactionKind.expense,
  amountMinor: minor,
  accountId: acc,
  categoryId: cat,
  occurredAt: at,
);

void main() {
  group('budget periods', () {
    final now = DateTime(2026, 9, 30, 15); // A Wednesday.

    test('weeks start on Monday; months and years on the 1st', () {
      expect(BudgetPeriod.daily.range(now), (
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
      ));
      expect(BudgetPeriod.weekly.range(now), (
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
      ));
      expect(BudgetPeriod.monthly.range(now), (
        DateTime(2026, 9),
        DateTime(2026, 10),
      ));
      expect(BudgetPeriod.yearly.range(now).$1, DateTime(2026));
    });
  });

  group('budget status', () {
    const food = Budget(
      id: 'b',
      categoryId: 'food',
      amountMinor: 1000000, // ₱10,000 a month
      period: BudgetPeriod.monthly,
    );
    final now = DateTime(2026, 9, 15, 12); // Half-way through September.

    BudgetStatus status(List<Transaction> t) =>
        BudgetStatus.of(food, t, now: now, inMainCurrency: (id) => id == 'php');

    test('counts only this category, this period, this currency', () {
      final s = status([
        _spend(DateTime(2026, 9, 2), 200000),
        _spend(DateTime(2026, 8, 30), 900000), // last month
        _spend(DateTime(2026, 9, 3), 900000, cat: 'fun'),
        _spend(DateTime(2026, 9, 4), 900000, acc: 'usd'),
      ]);
      expect(s.spentMinor, 200000);
      expect(s.remainingMinor, 800000);
      expect(s.pace, BudgetPace.onTrack);
    });

    test('spread what’s left over the days left, today included', () {
      final s = status([_spend(DateTime(2026, 9, 2), 400000)]);
      expect(s.daysLeft, 16); // 15th to 30th
      expect(s.dailyAllowanceMinor, 600000 ~/ 16);
    });

    test('flags fast spending and projects the month end', () {
      final s = status([_spend(DateTime(2026, 9, 10), 700000)]);
      expect(s.pace, BudgetPace.fast);
      expect(s.projectedMinor, greaterThan(1000000));
    });

    test('near the limit, then over', () {
      expect(
        status([_spend(DateTime(2026, 9, 14), 900000)]).pace,
        BudgetPace.nearLimit,
      );
      final over = status([_spend(DateTime(2026, 9, 14), 1200000)]);
      expect(over.pace, BudgetPace.over);
      expect(over.dailyAllowanceMinor, 0);
    });

    test('a small early purchase is not "fast"', () {
      final early = BudgetStatus.of(
        food,
        [_spend(DateTime(2026, 9, 1, 9), 150000)],
        now: DateTime(2026, 9, 1, 10),
        inMainCurrency: (_) => true,
      );
      expect(early.pace, BudgetPace.onTrack);
      expect(early.projectedMinor, isNull);
    });

    test('suggestions round last month up to a friendly number', () {
      // ₱1,234.56 → ₱1,300; ₱42.10 → ₱45; ₱8,700 → ₱9,000.
      expect(suggestedBudgetMinor(123456, minorPerUnit: 100), 130000);
      expect(suggestedBudgetMinor(870000, minorPerUnit: 100), 900000);
      expect(suggestedBudgetMinor(4210, minorPerUnit: 100), 4500);
      expect(suggestedBudgetMinor(0, minorPerUnit: 100), isNull);
    });
  });

  group('goal progress', () {
    final now = DateTime(2026, 9, 30);
    Goal goal({DateTime? by, DateTime? created}) => Goal(
      id: 'g',
      name: 'Trip',
      targetMinor: 1200000, // ₱12,000
      currencyCode: 'PHP',
      icon: 'travel',
      color: 'sky',
      createdAt: created ?? DateTime(2026, 6, 1),
      targetDate: by,
    );
    GoalEntry entry(int minor, DateTime at) =>
        GoalEntry(id: '$at', goalId: 'g', amountMinor: minor, occurredAt: at);

    test('sums entries, withdrawals included', () {
      final p = GoalProgress.of(goal(), [
        entry(500000, DateTime(2026, 7, 1)),
        entry(-100000, DateTime(2026, 8, 1)),
        entry(100000, DateTime(2026, 9, 1)),
      ], now: now);
      expect(p.savedMinor, 500000);
      expect(p.remainingMinor, 700000);
      expect(p.fraction, closeTo(5 / 12, 1e-9));
    });

    test('says what to set aside monthly, and whether the pace is enough', () {
      // ₱3,000 a month for the last 3 months.
      final entries = [
        entry(300000, DateTime(2026, 7, 5)),
        entry(300000, DateTime(2026, 8, 5)),
        entry(300000, DateTime(2026, 9, 5)),
      ];
      final soon = GoalProgress.of(
        goal(by: DateTime(2026, 10, 31)),
        entries,
        now: now,
      );
      expect(soon.monthlyNeededMinor, 300000); // ₱3,000 left, 1 month
      final far = GoalProgress.of(
        goal(by: DateTime(2027, 3, 1)),
        entries,
        now: now,
      );
      expect(far.health, GoalHealth.onTrack);
      final tight = GoalProgress.of(goal(by: DateTime(2026, 10, 5)), [
        entry(100000, DateTime(2026, 9, 5)),
      ], now: now);
      expect(tight.health, GoalHealth.behind);
    });

    test('reached, overdue and open goals', () {
      expect(
        GoalProgress.of(goal(), [
          entry(1200000, DateTime(2026, 9, 1)),
        ], now: now).health,
        GoalHealth.done,
      );
      expect(
        GoalProgress.of(
          goal(by: DateTime(2026, 9, 1)),
          const [],
          now: now,
        ).health,
        GoalHealth.overdue,
      );
      final open = GoalProgress.of(goal(), const [], now: now);
      expect(open.health, GoalHealth.open);
      expect(open.estimatedFinish, isNull);
    });

    test('a first deposit today isn’t read as a huge monthly pace', () {
      final p = GoalProgress.of(goal(created: now), [
        entry(100000, now),
      ], now: now);
      // Spread over at least a month.
      expect(p.monthlyPaceMinor, lessThanOrEqualTo(101500));
    });
  });
}
