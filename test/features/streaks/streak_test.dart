import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/streaks/domain/streak.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

final _now = DateTime(2026, 9, 28, 15); // A Monday afternoon.

DateTime _daysAgo(int n, [int hour = 12]) =>
    DateTime(_now.year, _now.month, _now.day - n, hour);

Transaction _spend(int daysAgo, int minor, {String account = 'php'}) =>
    Transaction(
      id: 'e$daysAgo-$minor',
      kind: TransactionKind.expense,
      amountMinor: minor,
      accountId: account,
      occurredAt: _daysAgo(daysAgo),
    );

Transaction _income(int daysAgo) => Transaction(
  id: 'i$daysAgo',
  kind: TransactionKind.income,
  amountMinor: 100,
  accountId: 'php',
  occurredAt: _daysAgo(daysAgo),
);

Streak _compute(
  List<Transaction> txns, {
  StreakSettings settings = const StreakSettings(restDays: false),
  int startedDaysAgo = 60,
}) => Streak.compute(
  transactions: txns,
  settings: settings,
  start: _daysAgo(startedDaysAgo, 9),
  now: _now,
  inMainCurrency: (id) => id == 'php',
);

void main() {
  group('daily logging', () {
    test('counts consecutive logged days, today included once logged', () {
      final s = _compute([_income(0), _spend(1, 50), _spend(2, 50)]);
      expect(s.current, 3);
      expect(s.today, TodayState.secured);
      expect(s.atRisk, isFalse);
    });

    test('an unlogged today keeps the streak alive, but at risk', () {
      final s = _compute([_spend(1, 50), _spend(2, 50)]);
      expect(s.current, 2);
      expect(s.today, TodayState.open);
      expect(s.atRisk, isTrue);
      expect(s.week.last.$2, DayMark.pending);
    });

    test('a missed day resets it, and best remembers the longer run', () {
      final s = _compute([
        _spend(0, 1),
        _spend(1, 1),
        // Day 2 missed.
        _spend(3, 1),
        _spend(4, 1),
        _spend(5, 1),
      ]);
      expect(s.current, 2);
      expect(s.best, 3);
      expect(s.week[4].$2, DayMark.missed);
    });

    test('several transactions on one day count once', () {
      final s = _compute([_spend(0, 1), _spend(0, 2), _income(0)]);
      expect(s.current, 1);
    });
  });

  group('rest days', () {
    const settings = StreakSettings(restDays: true);

    test('one missed day a week is forgiven, without adding to the count', () {
      // Today is Monday; yesterday (Sunday) was missed.
      final s = _compute([
        _spend(0, 1),
        _spend(2, 1),
        _spend(3, 1),
      ], settings: settings);
      expect(s.current, 3);
      expect(s.week[5].$2, DayMark.rest);
    });

    test('two missed days in a row are never forgiven', () {
      final s = _compute([
        _spend(0, 1),
        _spend(3, 1),
        _spend(4, 1),
      ], settings: settings);
      expect(s.current, 1);
    });

    test('only one rest day per week', () {
      // Thursday and Saturday missed in the same week.
      final s = _compute([
        _spend(1, 1),
        _spend(3, 1),
        _spend(5, 1),
        _spend(6, 1),
      ], settings: settings);
      // Saturday is forgiven; Thursday breaks it.
      expect(s.week[4].$2, DayMark.rest);
      expect(s.week[2].$2, DayMark.missed);
      expect(s.current, 2);
    });
  });

  group('daily cap', () {
    const cap = StreakSettings(
      goal: StreakGoal.underCap,
      capMinor: 50000,
      restDays: false,
    );

    test('finished days at or under the cap count; today counts tomorrow', () {
      final s = _compute(
        [_spend(0, 10000), _spend(1, 50000), _spend(2, 20000)],
        settings: cap,
        startedDaysAgo: 2,
      );
      expect(s.current, 2);
      expect(s.today, TodayState.open);
      expect(s.spentTodayMinor, 10000);
      expect(s.atRisk, isFalse);
    });

    test('going over today ends the streak right away', () {
      final s = _compute(
        [_spend(0, 60000), _spend(1, 100)],
        settings: cap,
        startedDaysAgo: 3,
      );
      expect(s.today, TodayState.over);
      expect(s.current, 0);
      expect(s.best, 3);
      expect(s.week.last.$2, DayMark.missed);
    });

    test('other currencies and income don’t count toward the cap', () {
      final s = _compute(
        [_spend(1, 900000, account: 'usd'), _income(1)],
        settings: cap,
        startedDaysAgo: 1,
      );
      expect(s.current, 1);
    });

    test('a zero cap is a no-spend streak that starts when you joined', () {
      const noSpend = StreakSettings(
        goal: StreakGoal.underCap,
        restDays: false,
      );
      expect(noSpend.isNoSpend, isTrue);
      final s = _compute([_spend(4, 1)], settings: noSpend, startedDaysAgo: 10);
      // Joined 10 days ago: days 10 to 5 were clean, day 4 wasn't.
      expect(s.current, 3);
      expect(s.best, 6);
      // Days before joining are neither counted nor missed.
      final fresh = _compute([], settings: noSpend, startedDaysAgo: 2);
      expect(fresh.current, 2);
      expect(fresh.week.first.$2, DayMark.notStarted);
    });
  });

  test('milestones: the next badge and the one behind', () {
    final s = _compute([for (var i = 0; i < 8; i++) _spend(i, 1)]);
    expect(s.current, 8);
    expect(s.lastMilestone, 7);
    expect(s.nextMilestone, 14);
  });
}
