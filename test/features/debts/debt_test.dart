import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/debts/domain/debt.dart';
import 'package:velora/features/debts/presentation/debt_style.dart';

void main() {
  final now = DateTime(2026, 9, 29, 15);
  final billEase = Debt(
    id: 'b',
    name: 'BillEase',
    kind: DebtKind.bnpl,
    currencyCode: 'PHP',
    owedMinor: 600000,
    monthlyMinor: 100000,
    dueDay: 5,
    createdAt: DateTime(2026, 8),
  );
  DebtEntry entry(String id, int amount) => DebtEntry(
    id: id,
    debtId: 'b',
    amountMinor: amount,
    occurredAt: DateTime(2026, 9, 5),
  );

  test('what is left, paid and borrowed, and months to go', () {
    final p = DebtProgress.of(billEase, [
      entry('1', 100000),
      entry('2', 100000),
      entry('3', -50000), // Borrowed ₱500 more.
      DebtEntry(
        id: 'x',
        debtId: 'someone-else',
        amountMinor: 999900,
        occurredAt: DateTime(2026),
      ),
    ], now: now);
    expect(p.paidMinor, 200000);
    expect(p.borrowedMinor, 50000);
    expect(p.totalMinor, 650000);
    expect(p.remainingMinor, 450000);
    expect(p.monthsLeft, 5); // ₱4,500 at ₱1,000 a month.
    expect(p.suggestedPaymentMinor, 100000);
    expect(p.fraction, closeTo(200000 / 650000, 1e-9));
    expect(p.isPaidOff, isFalse);
    expect(p.nextDue, DateTime(2026, 10, 5));
  });

  test('paying more than what is left counts as paid off', () {
    final p = DebtProgress.of(billEase, [entry('1', 700000)], now: now);
    expect(p.remainingMinor, 0);
    expect(p.isPaidOff, isTrue);
    expect(p.monthsLeft, isNull);
    expect(p.fraction, 1);
  });

  test('the next due date, in short months too', () {
    expect(nextDueDate(null, now), isNull);
    expect(nextDueDate(29, now), DateTime(2026, 9, 29)); // Today.
    expect(nextDueDate(30, now), DateTime(2026, 9, 30));
    expect(nextDueDate(5, now), DateTime(2026, 10, 5));
    // Due on the 31st: September has 30 days.
    expect(nextDueDate(31, DateTime(2026, 9, 10)), DateTime(2026, 9, 30));
    expect(nextDueDate(31, DateTime(2026, 2, 3)), DateTime(2026, 2, 28));
  });

  test('labels read naturally', () {
    expect(ordinal(1), '1st');
    expect(ordinal(2), '2nd');
    expect(ordinal(3), '3rd');
    expect(ordinal(11), '11th');
    expect(ordinal(22), '22nd');
    expect(dueLabel(DateTime(2026, 9, 29), now), 'Due today');
    expect(dueLabel(DateTime(2026, 9, 30), now), 'Due tomorrow');
    expect(dueLabel(DateTime(2026, 10, 5), now), 'Due Oct 5');
    final p = DebtProgress.of(billEase, [entry('1', 100000)], now: now);
    expect(debtOutlook(p, now), 'Due Oct 5 · ₱1,000/mo · about 5 months left');
  });

  test('totals over several debts', () {
    final a = DebtProgress.of(billEase, [entry('1', 100000)], now: now);
    final t = DebtTotals.of([a]);
    expect(t.owedMinor, 500000);
    expect(t.paidMinor, 100000);
    expect(t.totalMinor, 600000);
  });
}
