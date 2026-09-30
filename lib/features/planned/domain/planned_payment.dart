import 'dart:math' as math;

import '../../../core/time/app_clock.dart';
import '../../transactions/domain/transaction.dart';
import '../../../core/time/iso_date.dart';

enum PlannedRepeat {
  once('Once'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const PlannedRepeat(this.label);
  final String label;
}

/// A bill, subscription or expected income that comes round again.
class PlannedPayment {
  const PlannedPayment({
    required this.id,
    required this.kind,
    required this.name,
    required this.amountMinor,
    required this.accountId,
    required this.repeat,
    required this.nextDue,
    required this.createdAt,
    this.categoryId,
    this.every = 1,
    this.anchorDay,
    this.remindDays,
    this.autoLog = false,
    this.doneAt,
  });

  factory PlannedPayment.fromRow(Map<String, dynamic> row) => PlannedPayment(
    id: row['id'] as String,
    kind: row['kind'] == 'income'
        ? TransactionKind.income
        : TransactionKind.expense,
    name: row['name'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    accountId: row['account_id'] as String,
    categoryId: row['category_id'] as String?,
    repeat:
        PlannedRepeat.values.asNameMap()[row['repeat'] as String] ??
        PlannedRepeat.monthly,
    every: (row['every'] as num?)?.toInt() ?? 1,
    anchorDay: (row['anchor_day'] as num?)?.toInt(),
    nextDue: DateTime.parse(row['next_due'] as String),
    remindDays: (row['remind_days'] as num?)?.toInt(),
    autoLog: row['auto_log'] as bool? ?? false,
    doneAt: switch (row['done_at']) {
      final String d => AppClock.wall(DateTime.parse(d)),
      _ => null,
    },
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
  );

  final String id;

  /// Expense (a bill) or income (salary).
  final TransactionKind kind;
  final String name;
  final int amountMinor;
  final String accountId;
  final String? categoryId;
  final PlannedRepeat repeat;

  /// Every N weeks, months or years.
  final int every;

  /// The day of the month it falls on, for monthly and yearly.
  final int? anchorDay;

  /// The next date it's due, a calendar day.
  final DateTime nextDue;

  /// Days before the due date to remind (0 is on the day); null for none.
  final int? remindDays;

  /// Logged by itself on its date.
  final bool autoLog;

  /// Paid for good (a one-off) or stopped.
  final DateTime? doneAt;
  final DateTime createdAt;

  bool get isDone => doneAt != null;

  /// The same plan, due on [due] (after a payment moves it on).
  PlannedPayment dueOn(DateTime due) => PlannedPayment(
    id: id,
    kind: kind,
    name: name,
    amountMinor: amountMinor,
    accountId: accountId,
    categoryId: categoryId,
    repeat: repeat,
    every: every,
    anchorDay: anchorDay,
    nextDue: due,
    remindDays: remindDays,
    autoLog: autoLog,
    doneAt: doneAt,
    createdAt: createdAt,
  );
  bool get isIncome => kind == TransactionKind.income;

  /// The date after [from] it's due again, or null for a one-off.
  DateTime? nextAfter(DateTime from) =>
      nextOccurrence(repeat, every, anchorDay, from);

  PlannedDraft toDraft() => PlannedDraft(
    kind: kind,
    name: name,
    amountMinor: amountMinor,
    accountId: accountId,
    categoryId: categoryId,
    repeat: repeat,
    every: every,
    firstDue: nextDue,
    anchorDay: anchorDay,
    remindDays: remindDays,
    autoLog: autoLog,
  );
}

class PlannedDraft {
  const PlannedDraft({
    required this.kind,
    required this.name,
    required this.amountMinor,
    required this.accountId,
    required this.repeat,
    required this.firstDue,
    this.categoryId,
    this.every = 1,
    this.anchorDay,
    this.remindDays,
    this.autoLog = false,
  });

  final TransactionKind kind;
  final String name;
  final int amountMinor;
  final String accountId;
  final String? categoryId;
  final PlannedRepeat repeat;
  final int every;

  /// When it's next due.
  final DateTime firstDue;

  /// Defaults to [firstDue]'s day for monthly and yearly.
  final int? anchorDay;
  final int? remindDays;
  final bool autoLog;

  Map<String, Object?> toRow() => {
    'kind': kind == TransactionKind.income ? 'income' : 'expense',
    'name': name.trim(),
    'amount_minor': amountMinor,
    'account_id': accountId,
    'category_id': categoryId,
    'repeat': repeat.name,
    'every': every,
    'anchor_day': switch (repeat) {
      PlannedRepeat.monthly ||
      PlannedRepeat.yearly => anchorDay ?? firstDue.day,
      _ => null,
    },
    'next_due': isoDate(firstDue),
    'remind_days': remindDays,
    'auto_log': autoLog,
    // Saving one makes it active again, a stopped one included.
    'done_at': null,
  };
}

DateTime _clampedDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day, last));
}

/// The date after [from] a schedule comes round again, or null for once.
/// Monthly and yearly keep [anchorDay] (a bill due the 31st is due Feb 28,
/// then Mar 31 again).
DateTime? nextOccurrence(
  PlannedRepeat repeat,
  int every,
  int? anchorDay,
  DateTime from,
) {
  final n = math.max(1, every);
  final day = DateTime(from.year, from.month, from.day);
  return switch (repeat) {
    PlannedRepeat.once => null,
    PlannedRepeat.weekly => DateTime(day.year, day.month, day.day + 7 * n),
    PlannedRepeat.monthly => _clampedDay(
      day.year,
      day.month + n,
      anchorDay ?? day.day,
    ),
    PlannedRepeat.yearly => _clampedDay(
      day.year + n,
      day.month,
      anchorDay ?? day.day,
    ),
  };
}

/// Every date a planned payment falls due from [start] to [end] (both
/// days included), starting at its next due date. One-offs come once;
/// done ones never.
List<DateTime> occurrencesBetween(
  PlannedPayment p,
  DateTime start,
  DateTime end, {
  int max = 60,
}) {
  if (p.isDone) return const [];
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  final out = <DateTime>[];
  DateTime? d = p.nextDue;
  while (d != null && !d.isAfter(to) && out.length < max) {
    if (!d.isBefore(from)) out.add(d);
    d = p.nextAfter(d);
  }
  return out;
}

/// How soon it's due, for grouping the list.
enum DueStatus {
  overdue('Overdue'),
  today('Today'),
  soon('Next 7 days'),
  later('Later'),
  done('Done');

  const DueStatus(this.label);
  final String label;
}

DueStatus dueStatus(PlannedPayment p, DateTime now) {
  if (p.isDone) return DueStatus.done;
  final today = DateTime(now.year, now.month, now.day);
  final days = p.nextDue.difference(today).inDays;
  if (days < 0) return DueStatus.overdue;
  if (days == 0) return DueStatus.today;
  if (days <= 7) return DueStatus.soon;
  return DueStatus.later;
}

/// "Every month on the 15th", "Every 2 weeks", "Once".
String describeRepeat(PlannedPayment p) {
  String ordinal(int n) {
    final teen = n % 100 >= 11 && n % 100 <= 13;
    final s = teen
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$s';
  }

  final n = p.every;
  final day = p.anchorDay ?? p.nextDue.day;
  return switch (p.repeat) {
    PlannedRepeat.once => 'Once',
    PlannedRepeat.weekly => n == 1 ? 'Every week' : 'Every $n weeks',
    PlannedRepeat.monthly =>
      n == 1
          ? 'Every month on the ${ordinal(day)}'
          : 'Every $n months on the ${ordinal(day)}',
    PlannedRepeat.yearly => n == 1 ? 'Every year' : 'Every $n years',
  };
}

/// What's coming up over a window: out and in, and how many.
class UpcomingTotals {
  UpcomingTotals.of(
    Iterable<PlannedPayment> planned,
    DateTime start,
    DateTime end,
  ) : outMinor = _sum(planned, start, end, income: false),
      inMinor = _sum(planned, start, end, income: true),
      count = planned.fold(
        0,
        (s, p) => s + occurrencesBetween(p, start, end).length,
      );

  static int _sum(
    Iterable<PlannedPayment> planned,
    DateTime start,
    DateTime end, {
    required bool income,
  }) => planned
      .where((p) => p.isIncome == income)
      .fold(
        0,
        (s, p) => s + occurrencesBetween(p, start, end).length * p.amountMinor,
      );

  final int outMinor;
  final int inMinor;
  final int count;
}
