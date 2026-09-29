import 'dart:math' as math;

import '../../../core/time/app_clock.dart';

enum DebtKind {
  card('Credit card'),
  bnpl('Pay later'),
  loan('Loan'),
  personal('Borrowed from someone');

  const DebtKind(this.label);
  final String label;
}

/// Something the user owes. What's left comes from its [DebtEntry]s.
class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.owedMinor,
    required this.createdAt,
    this.monthlyMinor,
    this.dueDay,
  });

  factory Debt.fromRow(Map<String, dynamic> row) => Debt(
    id: row['id'] as String,
    name: row['name'] as String,
    kind: DebtKind.values.asNameMap()[row['kind'] as String] ?? DebtKind.loan,
    currencyCode: row['currency_code'] as String,
    owedMinor: (row['owed_minor'] as num).toInt(),
    monthlyMinor: (row['monthly_minor'] as num?)?.toInt(),
    dueDay: (row['due_day'] as num?)?.toInt(),
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
  );

  final String id;
  final String name;
  final DebtKind kind;
  final String currencyCode;

  /// What was owed when it was added.
  final int owedMinor;

  /// The usual payment, if there is one.
  final int? monthlyMinor;

  /// The day of the month it's due (1 to 31), if it has one.
  final int? dueDay;
  final DateTime createdAt;

  DebtDraft toDraft() => DebtDraft(
    name: name,
    kind: kind,
    currencyCode: currencyCode,
    owedMinor: owedMinor,
    monthlyMinor: monthlyMinor,
    dueDay: dueDay,
  );
}

class DebtDraft {
  const DebtDraft({
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.owedMinor,
    this.monthlyMinor,
    this.dueDay,
  });

  final String name;
  final DebtKind kind;
  final String currencyCode;
  final int owedMinor;
  final int? monthlyMinor;
  final int? dueDay;

  Map<String, Object?> toRow() => {
    'name': name.trim(),
    'kind': kind.name,
    'currency_code': currencyCode,
    'owed_minor': owedMinor,
    'monthly_minor': monthlyMinor,
    'due_day': dueDay,
  };
}

/// A payment (positive) or more borrowed (negative).
class DebtEntry {
  const DebtEntry({
    required this.id,
    required this.debtId,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
    this.transactionId,
  });

  factory DebtEntry.fromRow(Map<String, dynamic> row) => DebtEntry(
    id: row['id'] as String,
    debtId: row['debt_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    note: row['note'] as String?,
    occurredAt: AppClock.wall(DateTime.parse(row['occurred_at'] as String)),
    transactionId: row['transaction_id'] as String?,
  );

  final String id;
  final String debtId;
  final int amountMinor;
  final String? note;
  final DateTime occurredAt;

  /// The expense that paid it, if it came out of an account.
  final String? transactionId;

  bool get isPayment => amountMinor > 0;
}

/// Where a debt stands.
class DebtProgress {
  DebtProgress._({
    required this.debt,
    required this.entries,
    required this.paidMinor,
    required this.borrowedMinor,
    required this.nextDue,
  });

  /// [entries] may hold every debt's; only this one's count. Newest first.
  factory DebtProgress.of(
    Debt debt,
    Iterable<DebtEntry> entries, {
    required DateTime now,
  }) {
    final mine = entries.where((e) => e.debtId == debt.id).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    var paid = 0, borrowed = 0;
    for (final e in mine) {
      if (e.amountMinor > 0) {
        paid += e.amountMinor;
      } else {
        borrowed -= e.amountMinor;
      }
    }
    return DebtProgress._(
      debt: debt,
      entries: mine,
      paidMinor: paid,
      borrowedMinor: borrowed,
      nextDue: nextDueDate(debt.dueDay, now),
    );
  }

  final Debt debt;
  final List<DebtEntry> entries;
  final int paidMinor;
  final int borrowedMinor;

  /// The next time a payment is due, if the debt has a due day.
  final DateTime? nextDue;

  /// Everything ever owed on it: the start plus anything borrowed since.
  int get totalMinor => debt.owedMinor + borrowedMinor;

  int get remainingMinor => math.max(0, totalMinor - paidMinor);
  bool get isPaidOff => remainingMinor == 0;

  /// 0 to 1: how much has been paid off.
  double get fraction =>
      totalMinor == 0 ? 1 : (paidMinor / totalMinor).clamp(0.0, 1.0);

  /// Months to go at the usual payment, if there is one.
  int? get monthsLeft => switch (debt.monthlyMinor) {
    final m? when !isPaidOff => (remainingMinor / m).ceil(),
    _ => null,
  };

  /// What a payment usually is: the monthly amount, but never more than
  /// what's left.
  int get suggestedPaymentMinor => switch (debt.monthlyMinor) {
    final m? => math.min(m, remainingMinor),
    null => remainingMinor,
  };
}

/// The next date on or after today with [dueDay], moved to the month's
/// last day in shorter months (a debt due on the 31st is due Feb 28).
DateTime? nextDueDate(int? dueDay, DateTime now) {
  if (dueDay == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  DateTime inMonth(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, math.min(dueDay, last));
  }

  final thisMonth = inMonth(today.year, today.month);
  return thisMonth.isBefore(today)
      ? inMonth(today.year, today.month + 1)
      : thisMonth;
}

/// All debts in one currency, summed.
class DebtTotals {
  DebtTotals.of(Iterable<DebtProgress> debts)
    : owedMinor = debts.fold(0, (s, d) => s + d.remainingMinor),
      paidMinor = debts.fold(0, (s, d) => s + d.paidMinor),
      totalMinor = debts.fold(0, (s, d) => s + d.totalMinor);

  /// Still to pay.
  final int owedMinor;
  final int paidMinor;
  final int totalMinor;

  double get fraction =>
      totalMinor == 0 ? 0 : (paidMinor / totalMinor).clamp(0.0, 1.0);
}
