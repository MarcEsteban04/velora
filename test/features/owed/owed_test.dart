import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/owed/domain/owed.dart';
import 'package:velora/features/owed/presentation/owed_style.dart';

void main() {
  final now = DateTime(2026, 9, 30, 15);
  final juan = Owed(
    id: 'j',
    name: 'Juan',
    note: 'Concert tickets',
    currencyCode: 'PHP',
    dueOn: DateTime(2026, 10, 15),
    createdAt: DateTime(2026, 9),
  );
  OwedEntry entry(String id, int amount, DateTime at) =>
      OwedEntry(id: id, owedId: 'j', amountMinor: amount, occurredAt: at);

  test('what is still owed: lent, less what came back', () {
    final p = OwedProgress.of(juan, [
      entry('1', -200000, DateTime(2026, 9, 1)), // Lent ₱2,000.
      entry('2', -50000, DateTime(2026, 9, 10)), // And ₱500 more.
      entry('3', 100000, DateTime(2026, 9, 20)), // ₱1,000 back.
      OwedEntry(
        id: 'x',
        owedId: 'someone-else',
        amountMinor: -999900,
        occurredAt: DateTime(2026),
      ),
    ]);
    expect(p.lentMinor, 250000);
    expect(p.backMinor, 100000);
    expect(p.remainingMinor, 150000);
    expect(p.fraction, closeTo(0.4, 1e-9));
    expect(p.isSettled, isFalse);
    expect(p.lentOn, DateTime(2026, 9, 1));
    expect(p.entries.map((e) => e.id), ['3', '2', '1']);
  });

  test('paying back more than is owed counts as settled', () {
    final p = OwedProgress.of(juan, [
      entry('1', -200000, DateTime(2026, 9, 1)),
      entry('2', 250000, DateTime(2026, 9, 20)),
    ]);
    expect(p.remainingMinor, 0);
    expect(p.isSettled, isTrue);
    expect(p.fraction, 1);
    // Settled is never overdue.
    expect(p.isOverdue(DateTime(2026, 11, 1)), isFalse);
  });

  test('overdue once the pay-back day has passed', () {
    final p = OwedProgress.of(juan, [
      entry('1', -200000, DateTime(2026, 9, 1)),
    ]);
    expect(p.isOverdue(now), isFalse);
    expect(p.isOverdue(DateTime(2026, 10, 15, 23)), isFalse); // The day itself.
    expect(p.isOverdue(DateTime(2026, 10, 16)), isTrue);
    expect(payBackLabel(DateTime(2026, 10, 15), now), 'Pay back by Oct 15');
    expect(payBackLabel(DateTime(2026, 9, 30), now), 'Pay back today');
    expect(payBackLabel(DateTime(2026, 10, 1), now), 'Pay back tomorrow');
    expect(payBackLabel(DateTime(2026, 9, 20), now), 'Overdue since Sep 20');
    expect(owedOutlook(p, now), 'Concert tickets · Pay back by Oct 15');
  });

  test('totals over several people', () {
    final maria = Owed(
      id: 'm',
      name: 'Maria Santos',
      currencyCode: 'PHP',
      createdAt: DateTime(2026, 9),
    );
    final all = [
      OwedProgress.of(juan, [entry('1', -200000, DateTime(2026, 9, 1))]),
      OwedProgress.of(maria, [
        OwedEntry(
          id: 'm1',
          owedId: 'm',
          amountMinor: -100000,
          occurredAt: DateTime(2026, 9, 2),
        ),
        OwedEntry(
          id: 'm2',
          owedId: 'm',
          amountMinor: 40000,
          occurredAt: DateTime(2026, 9, 3),
        ),
      ]),
    ];
    final t = OwedTotals.of(all);
    expect(t.owedMinor, 260000);
    expect(t.lentMinor, 300000);
    expect(t.backMinor, 40000);
    expect(maria.initials, 'MS');
    expect(juan.initials, 'J');
  });

  test('the reminder names what it was for and when', () {
    final gcash = Owed(
      id: 'j',
      name: 'Juan',
      note: 'GCash load',
      currencyCode: 'PHP',
      createdAt: now,
    );
    expect(
      owedReminder(
        OwedProgress.of(gcash, [entry('1', -10000, DateTime(2026, 9, 1))]),
        '₱100.00',
      ),
      contains('for GCash load.'),
    );
    final p = OwedProgress.of(juan, [
      entry('1', -200000, DateTime(2026, 9, 1)),
    ]);
    expect(
      owedReminder(p, '₱2,000.00'),
      'Hi Juan! Just a friendly reminder about the ₱2,000.00 for concert '
      'tickets. Could you send it by Oct 15? Thank you!',
    );
    final plain = OwedProgress.of(
      Owed(id: 'j', name: 'Juan', currencyCode: 'PHP', createdAt: now),
      [entry('1', -50000, DateTime(2026, 9, 1))],
    );
    expect(
      owedReminder(plain, '₱500.00'),
      'Hi Juan! Just a friendly reminder about the ₱500.00. Could you send '
      'it? Thank you!',
    );
  });
}
