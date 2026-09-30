import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/planned/domain/planned_payment.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

void main() {
  PlannedPayment plan({
    PlannedRepeat repeat = PlannedRepeat.monthly,
    int every = 1,
    int? anchor,
    required DateTime due,
    bool income = false,
    int amount = 245000,
    DateTime? done,
  }) => PlannedPayment(
    id: 'p',
    kind: income ? TransactionKind.income : TransactionKind.expense,
    name: 'Meralco',
    amountMinor: amount,
    accountId: 'cash',
    repeat: repeat,
    every: every,
    anchorDay: anchor,
    nextDue: due,
    doneAt: done,
    createdAt: DateTime(2026),
  );

  group('the next date', () {
    test('monthly keeps its day, even past a short month', () {
      final p = plan(anchor: 31, due: DateTime(2026, 1, 31));
      final feb = p.nextAfter(DateTime(2026, 1, 31))!;
      expect(feb, DateTime(2026, 2, 28));
      // Back to the 31st in March, not stuck on the 28th.
      expect(p.nextAfter(feb), DateTime(2026, 3, 31));
      expect(p.nextAfter(DateTime(2026, 3, 31)), DateTime(2026, 4, 30));
    });

    test('every 2 weeks, every 3 months, yearly on a leap day, once', () {
      expect(
        nextOccurrence(PlannedRepeat.weekly, 2, null, DateTime(2026, 9, 25)),
        DateTime(2026, 10, 9),
      );
      expect(
        nextOccurrence(PlannedRepeat.monthly, 3, 15, DateTime(2026, 11, 15)),
        DateTime(2027, 2, 15),
      );
      expect(
        nextOccurrence(PlannedRepeat.yearly, 1, 29, DateTime(2028, 2, 29)),
        DateTime(2029, 2, 28),
      );
      expect(
        nextOccurrence(PlannedRepeat.once, 1, null, DateTime(2026, 9, 1)),
        isNull,
      );
    });

    test('across a year end', () {
      expect(
        nextOccurrence(PlannedRepeat.monthly, 1, 5, DateTime(2026, 12, 5)),
        DateTime(2027, 1, 5),
      );
    });
  });

  test('occurrences in a window, and what is coming up', () {
    final meralco = plan(anchor: 15, due: DateTime(2026, 10, 15));
    final gym = PlannedPayment(
      id: 'g',
      kind: TransactionKind.expense,
      name: 'Gym',
      amountMinor: 50000,
      accountId: 'cash',
      repeat: PlannedRepeat.weekly,
      nextDue: DateTime(2026, 10, 1),
      createdAt: DateTime(2026),
    );
    final salary = plan(
      due: DateTime(2026, 10, 10),
      anchor: 10,
      income: true,
      amount: 3000000,
    );
    final start = DateTime(2026, 9, 30), end = DateTime(2026, 10, 29);
    expect(occurrencesBetween(meralco, start, end), [DateTime(2026, 10, 15)]);
    expect(occurrencesBetween(gym, start, end), [
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 8),
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 22),
      DateTime(2026, 10, 29),
    ]);
    final t = UpcomingTotals.of([meralco, gym, salary], start, end);
    expect(t.outMinor, 245000 + 5 * 50000);
    expect(t.inMinor, 3000000);
    expect(t.count, 7);
    // Done ones don't come round.
    expect(
      occurrencesBetween(
        plan(due: DateTime(2026, 10, 1), done: DateTime(2026, 9, 1)),
        start,
        end,
      ),
      isEmpty,
    );
  });

  test('how soon, and how it reads', () {
    final now = DateTime(2026, 9, 30, 10);
    expect(dueStatus(plan(due: DateTime(2026, 9, 28)), now), DueStatus.overdue);
    expect(dueStatus(plan(due: DateTime(2026, 9, 30)), now), DueStatus.today);
    expect(dueStatus(plan(due: DateTime(2026, 10, 7)), now), DueStatus.soon);
    expect(dueStatus(plan(due: DateTime(2026, 10, 8)), now), DueStatus.later);
    expect(
      describeRepeat(plan(anchor: 15, due: DateTime(2026, 10, 15))),
      'Every month on the 15th',
    );
    expect(
      describeRepeat(
        plan(
          repeat: PlannedRepeat.weekly,
          every: 2,
          due: DateTime(2026, 10, 1),
        ),
      ),
      'Every 2 weeks',
    );
    expect(
      describeRepeat(
        plan(repeat: PlannedRepeat.once, due: DateTime(2026, 10, 1)),
      ),
      'Once',
    );
  });

  test('a draft keeps the due day as the anchor for monthly', () {
    final row = PlannedDraft(
      kind: TransactionKind.expense,
      name: ' Rent ',
      amountMinor: 1500000,
      accountId: 'bpi',
      repeat: PlannedRepeat.monthly,
      firstDue: DateTime(2026, 10, 31),
    ).toRow();
    expect(row['name'], 'Rent');
    expect(row['anchor_day'], 31);
    expect(row['next_due'], '2026-10-31');
    expect(row['kind'], 'expense');
  });
}
