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
    // The usual ₱1,000 plus the ₱500 bought, both on the next bill.
    expect(p.suggestedPaymentMinor, 150000);
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

  group('credit lines', () {
    final spay = Debt(
      id: 's',
      name: 'SPayLater',
      kind: DebtKind.bnpl,
      currencyCode: 'PHP',
      owedMinor: 100000, // ₱1,000 owed when added.
      dueDay: 15,
      creditLimitMinor: 2000000,
      createdAt: DateTime(2026, 8),
    );
    // ₱3,359 bought on Sep 20, paid over 3 months.
    final purchase = DebtEntry(
      id: 'p',
      debtId: 's',
      amountMinor: -335900,
      installments: 3,
      occurredAt: DateTime(2026, 9, 20),
    );

    test('available credit and how much of it is used', () {
      final p = DebtProgress.of(spay, [purchase], now: now);
      expect(p.remainingMinor, 435900);
      expect(p.availableMinor, 1564100);
      expect(p.usedFraction, closeTo(435900 / 2000000, 1e-9));
      // No limit, no available credit.
      final none = DebtProgress.of(
        Debt(
          id: 'x',
          name: 'Loan',
          kind: DebtKind.loan,
          currencyCode: 'PHP',
          owedMinor: 500000,
          createdAt: DateTime(2026),
        ),
        const [],
        now: now,
      );
      expect(none.availableMinor, isNull);
    });

    test('without a bill, the installment due this cycle is estimated', () {
      final p = DebtProgress.of(spay, [purchase], now: now);
      // ₱3,359 over 3 months: ₱1,119.66 on the first bill (Oct 15).
      expect(p.dueNowMinor, 111966);
      expect(p.dueFromBill, isFalse);
      expect(p.dueOn, DateTime(2026, 10, 15));
      expect(p.suggestedPaymentMinor, 111966);
    });

    test('the last installment carries the odd centavos', () {
      final later = DateTime(2026, 12, 20);
      final p = DebtProgress.of(spay, [purchase], now: later);
      // Bills: Oct 15, Nov 15, Dec 15 (k = 2 on the third).
      expect(p.dueNowMinor, isNotNull);
      final third = DebtProgress.of(spay, [
        purchase,
      ], now: DateTime(2026, 12, 1));
      expect(third.dueOn, DateTime(2026, 12, 15));
      expect(third.dueNowMinor, 335900 - 111966 * 2);
    });

    test('a scanned bill wins, and payments since it count against it', () {
      final billed = Debt(
        id: 's',
        name: 'SPayLater',
        kind: DebtKind.bnpl,
        currencyCode: 'PHP',
        owedMinor: 100000,
        dueDay: 15,
        creditLimitMinor: 2000000,
        billDueMinor: 161967,
        billDueOn: DateTime(2026, 10, 15),
        billSetAt: DateTime(2026, 9, 25),
        createdAt: DateTime(2026, 8),
      );
      final untouched = DebtProgress.of(billed, [purchase], now: now);
      expect(untouched.dueNowMinor, 161967);
      expect(untouched.dueFromBill, isTrue);
      expect(untouched.dueOn, DateTime(2026, 10, 15));

      final paid = DebtProgress.of(billed, [
        purchase,
        DebtEntry(
          id: 'pay',
          debtId: 's',
          amountMinor: 50000,
          occurredAt: DateTime(2026, 9, 27),
        ),
      ], now: now);
      expect(paid.dueNowMinor, 111967);
      // A payment from before the bill was set doesn't count.
      final before = DebtProgress.of(billed, [
        purchase,
        DebtEntry(
          id: 'old',
          debtId: 's',
          amountMinor: 50000,
          occurredAt: DateTime(2026, 9, 1),
        ),
      ], now: now);
      expect(before.dueNowMinor, 161967);
    });

    test('nothing due once it is all paid', () {
      final p = DebtProgress.of(spay, [
        purchase,
        DebtEntry(
          id: 'all',
          debtId: 's',
          amountMinor: 435900,
          occurredAt: DateTime(2026, 9, 28),
        ),
      ], now: now);
      expect(p.isPaidOff, isTrue);
      expect(p.dueNowMinor, 0);
      expect(p.availableMinor, 2000000);
    });
  });

  test('more borrowed on a loan is not billed as an installment', () {
    final loan = Debt(
      id: 'l',
      name: 'Salary loan',
      kind: DebtKind.loan,
      currencyCode: 'PHP',
      owedMinor: 1000000,
      monthlyMinor: 200000,
      dueDay: 20,
      createdAt: DateTime(2026, 8),
    );
    final p = DebtProgress.of(loan, [
      DebtEntry(
        id: 'b',
        debtId: 'l',
        amountMinor: -300000,
        occurredAt: DateTime(2026, 9, 10),
      ),
    ], now: now);
    expect(p.dueNowMinor, 200000); // Just the monthly payment.
  });
}
