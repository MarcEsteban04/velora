import 'dart:math' as math;

import '../../../core/time/app_clock.dart';

enum DebtKind {
  card('Credit card'),
  bnpl('Pay later'),
  loan('Loan'),
  personal('Borrowed from someone');

  const DebtKind(this.label);
  final String label;

  /// Cards and pay-later plans have a credit limit and monthly bills.
  bool get isCreditLine => this == card || this == bnpl;
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
    this.creditLimitMinor,
    this.billDueMinor,
    this.billDueOn,
    this.billSetAt,
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
    // Reads tolerate a database without the credit-line migration yet.
    creditLimitMinor: (row['credit_limit_minor'] as num?)?.toInt(),
    billDueMinor: (row['bill_due_minor'] as num?)?.toInt(),
    billDueOn: switch (row['bill_due_on']) {
      final String d => DateTime.parse(d),
      _ => null,
    },
    billSetAt: switch (row['bill_set_at']) {
      final String d => AppClock.wall(DateTime.parse(d)),
      _ => null,
    },
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

  /// The most it can owe (a card's or pay-later plan's limit), if known.
  final int? creditLimitMinor;

  /// The latest bill: what it asked for and when it's due. Payments made
  /// after [billSetAt] count against it.
  final int? billDueMinor;
  final DateTime? billDueOn;
  final DateTime? billSetAt;

  DebtDraft toDraft() => DebtDraft(
    name: name,
    kind: kind,
    currencyCode: currencyCode,
    owedMinor: owedMinor,
    monthlyMinor: monthlyMinor,
    dueDay: dueDay,
    creditLimitMinor: creditLimitMinor,
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
    this.creditLimitMinor,
  });

  final String name;
  final DebtKind kind;
  final String currencyCode;
  final int owedMinor;
  final int? monthlyMinor;
  final int? dueDay;
  final int? creditLimitMinor;

  /// The bill isn't part of it: editing a debt keeps its latest bill.
  Map<String, Object?> toRow() => {
    'name': name.trim(),
    'kind': kind.name,
    'currency_code': currencyCode,
    'owed_minor': owedMinor,
    'monthly_minor': monthlyMinor,
    'due_day': dueDay,
    'credit_limit_minor': kind.isCreditLine ? creditLimitMinor : null,
  };
}

/// A payment (positive) or more borrowed (negative), such as a purchase
/// paid over [installments] months.
class DebtEntry {
  const DebtEntry({
    required this.id,
    required this.debtId,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
    this.transactionId,
    this.installments,
  });

  factory DebtEntry.fromRow(Map<String, dynamic> row) => DebtEntry(
    id: row['id'] as String,
    debtId: row['debt_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    note: row['note'] as String?,
    occurredAt: AppClock.wall(DateTime.parse(row['occurred_at'] as String)),
    transactionId: row['transaction_id'] as String?,
    installments: (row['installments'] as num?)?.toInt(),
  );

  final String id;
  final String debtId;
  final int amountMinor;
  final String? note;
  final DateTime occurredAt;

  /// The expense that paid it, if it came out of an account.
  final String? transactionId;

  /// Months a purchase is split over (null or 1: pay in full).
  final int? installments;

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
    required this.dueNowMinor,
    required this.dueFromBill,
    required this.dueOn,
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
    final next = nextDueDate(debt.dueDay, now);
    final remaining = math.max(0, debt.owedMinor + borrowed - paid);
    final (due, fromBill, dueOn) = _dueNow(debt, mine, next, remaining);
    return DebtProgress._(
      debt: debt,
      entries: mine,
      paidMinor: paid,
      borrowedMinor: borrowed,
      nextDue: next,
      dueNowMinor: due,
      dueFromBill: fromBill,
      dueOn: dueOn,
    );
  }

  /// What's due now: the latest bill less what's been paid since, or, with
  /// no bill, an estimate from the monthly payment and the installments
  /// falling due this cycle less what's been paid this cycle.
  static (int?, bool, DateTime?) _dueNow(
    Debt debt,
    List<DebtEntry> entries,
    DateTime? next,
    int remaining,
  ) {
    int paidAfter(DateTime from) => entries
        .where((e) => e.isPayment && e.occurredAt.isAfter(from))
        .fold(0, (s, e) => s + e.amountMinor);

    if (debt.billDueMinor case final bill? when debt.billSetAt != null) {
      final left = math.max(0, bill - paidAfter(debt.billSetAt!));
      return (math.min(left, remaining), true, debt.billDueOn ?? next);
    }
    if (next == null || debt.dueDay == null) return (null, false, null);

    var due = remaining > 0 ? debt.monthlyMinor ?? 0 : 0;
    var estimable = debt.monthlyMinor != null;
    // Only cards and pay-later plans bill what's bought on them; more
    // borrowed on a loan or from a friend has no bill of its own.
    final purchases = debt.kind.isCreditLine
        ? entries.where((e) => !e.isPayment)
        : const <DebtEntry>[];
    for (final e in purchases) {
      estimable = true;
      final total = -e.amountMinor;
      final n = math.max(1, e.installments ?? 1);
      // The first bill after the purchase, then one a month.
      final first = nextDueDate(
        debt.dueDay,
        DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day + 1),
      )!;
      final k = (next.year - first.year) * 12 + next.month - first.month;
      if (k < 0 || k >= n) continue;
      final each = total ~/ n;
      due += k == n - 1 ? total - each * (n - 1) : each;
    }
    if (!estimable) return (null, false, null);
    final cycleStart = previousDueDate(debt.dueDay!, next);
    final left = math.max(0, due - paidAfter(cycleStart));
    return (math.min(left, remaining), false, next);
  }

  final Debt debt;
  final List<DebtEntry> entries;
  final int paidMinor;
  final int borrowedMinor;

  /// The next time a payment is due, if the debt has a due day.
  final DateTime? nextDue;

  /// What still needs paying for the current bill, when that's known.
  final int? dueNowMinor;

  /// Whether [dueNowMinor] comes from a real bill (else it's an estimate).
  final bool dueFromBill;

  /// When [dueNowMinor] is due.
  final DateTime? dueOn;

  /// Everything ever owed on it: the start plus anything borrowed since.
  int get totalMinor => debt.owedMinor + borrowedMinor;

  int get remainingMinor => math.max(0, totalMinor - paidMinor);
  bool get isPaidOff => remainingMinor == 0;

  /// How much more can be spent on it, when it has a credit limit.
  int? get availableMinor => switch (debt.creditLimitMinor) {
    final limit? => math.max(0, limit - remainingMinor),
    null => null,
  };

  /// 0 to 1: how much of the limit is used, when there is one.
  double? get usedFraction => switch (debt.creditLimitMinor) {
    final limit? => (remainingMinor / limit).clamp(0.0, 1.0),
    null => null,
  };

  /// 0 to 1: how much has been paid off.
  double get fraction =>
      totalMinor == 0 ? 1 : (paidMinor / totalMinor).clamp(0.0, 1.0);

  /// Months to go at the usual payment, if there is one.
  int? get monthsLeft => switch (debt.monthlyMinor) {
    final m? when !isPaidOff => (remainingMinor / m).ceil(),
    _ => null,
  };

  /// What a payment usually is: what's due now when known, else the
  /// monthly amount, but never more than what's left.
  int get suggestedPaymentMinor => switch ((dueNowMinor, debt.monthlyMinor)) {
    (final due?, _) when due > 0 => due,
    (_, final m?) => math.min(m, remainingMinor),
    _ => remainingMinor,
  };
}

DateTime _dayInMonth(int dueDay, int year, int month) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(dueDay, last));
}

/// The next date on or after today with [dueDay], moved to the month's
/// last day in shorter months (a debt due on the 31st is due Feb 28).
DateTime? nextDueDate(int? dueDay, DateTime now) {
  if (dueDay == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final thisMonth = _dayInMonth(dueDay, today.year, today.month);
  return thisMonth.isBefore(today)
      ? _dayInMonth(dueDay, today.year, today.month + 1)
      : thisMonth;
}

/// The due date the month before [next]: where the current cycle began.
DateTime previousDueDate(int dueDay, DateTime next) =>
    _dayInMonth(dueDay, next.year, next.month - 1);

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
