import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../core/time/app_clock.dart';

/// Someone who owes the user money. What's still owed comes from its
/// [OwedEntry]s: what was lent, less what's been paid back.
class Owed {
  const Owed({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.createdAt,
    this.note,
    this.dueOn,
  });

  factory Owed.fromRow(Map<String, dynamic> row) => Owed(
    id: row['id'] as String,
    name: row['name'] as String,
    note: row['note'] as String?,
    currencyCode: row['currency_code'] as String,
    dueOn: switch (row['due_on']) {
      final String d => DateTime.parse(d),
      _ => null,
    },
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
  );

  final String id;

  /// Who owes it.
  final String name;

  /// What it was for.
  final String? note;
  final String currencyCode;

  /// When they said they'd pay it back, if they did (a date, no time).
  final DateTime? dueOn;
  final DateTime createdAt;

  OwedDraft toDraft() => OwedDraft(
    name: name,
    note: note,
    currencyCode: currencyCode,
    dueOn: dueOn,
  );
}

/// Who, what for, the currency and the pay-back date. What was lent is an
/// entry, not part of it.
class OwedDraft {
  const OwedDraft({
    required this.name,
    required this.currencyCode,
    this.note,
    this.dueOn,
  });

  final String name;
  final String? note;
  final String currencyCode;
  final DateTime? dueOn;

  Map<String, Object?> toRow() => {
    'name': name.trim(),
    'note': switch (note?.trim()) {
      final n? when n.isNotEmpty => n,
      _ => null,
    },
    'currency_code': currencyCode,
    'due_on': dueOn == null ? null : dateOnly(dueOn!),
  };
}

/// "2026-11-15".
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Paid back (positive) or lent (negative).
class OwedEntry {
  const OwedEntry({
    required this.id,
    required this.owedId,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
    this.transactionId,
  });

  factory OwedEntry.fromRow(Map<String, dynamic> row) => OwedEntry(
    id: row['id'] as String,
    owedId: row['owed_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    note: row['note'] as String?,
    occurredAt: AppClock.wall(DateTime.parse(row['occurred_at'] as String)),
    transactionId: row['transaction_id'] as String?,
  );

  final String id;
  final String owedId;
  final int amountMinor;
  final String? note;
  final DateTime occurredAt;

  /// The expense (lent from an account) or income (paid back into one).
  final String? transactionId;

  bool get isRepayment => amountMinor > 0;
}

/// Where it stands.
class OwedProgress {
  OwedProgress._({
    required this.owed,
    required this.entries,
    required this.lentMinor,
    required this.backMinor,
  });

  /// [entries] may hold everyone's; only this one's count. Newest first.
  factory OwedProgress.of(Owed owed, Iterable<OwedEntry> entries) {
    final mine = entries.where((e) => e.owedId == owed.id).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    var lent = 0, back = 0;
    for (final e in mine) {
      if (e.isRepayment) {
        back += e.amountMinor;
      } else {
        lent -= e.amountMinor;
      }
    }
    return OwedProgress._(
      owed: owed,
      entries: mine,
      lentMinor: lent,
      backMinor: back,
    );
  }

  final Owed owed;
  final List<OwedEntry> entries;

  /// Everything lent to them.
  final int lentMinor;

  /// Everything they've paid back.
  final int backMinor;

  int get remainingMinor => math.max(0, lentMinor - backMinor);
  bool get isSettled => remainingMinor == 0;

  /// 0 to 1: how much has come back.
  double get fraction =>
      lentMinor == 0 ? 1 : (backMinor / lentMinor).clamp(0.0, 1.0);

  /// When it was first lent, if it has been.
  DateTime? get lentOn =>
      entries.where((e) => !e.isRepayment).lastOrNull?.occurredAt;

  /// Past the day they said they'd pay it back, and still owing.
  bool isOverdue(DateTime now) => switch (owed.dueOn) {
    final d? when !isSettled => d.isBefore(
      DateTime(now.year, now.month, now.day),
    ),
    _ => false,
  };
}

/// Everyone in one currency, summed.
class OwedTotals {
  OwedTotals.of(Iterable<OwedProgress> all)
    : owedMinor = all.fold(0, (s, p) => s + p.remainingMinor),
      backMinor = all.fold(0, (s, p) => s + p.backMinor),
      lentMinor = all.fold(0, (s, p) => s + p.lentMinor);

  /// Still owed to the user.
  final int owedMinor;
  final int backMinor;
  final int lentMinor;

  double get fraction =>
      lentMinor == 0 ? 0 : (backMinor / lentMinor).clamp(0.0, 1.0);
}

/// A friendly nudge to paste into a chat: "Hi Juan! Just a friendly
/// reminder about the ₱2,000.00 for concert tickets. Could you send it by
/// Oct 15? Thank you!".
String owedReminder(OwedProgress p, String amount) {
  final what = switch (p.owed.note?.trim()) {
    final n? when n.isNotEmpty => ' for ${_midSentence(n)}',
    _ => '',
  };
  final by = switch (p.owed.dueOn) {
    final d? => ' by ${DateFormat('MMM d').format(d)}',
    null => '',
  };
  return 'Hi ${p.owed.name}! Just a friendly reminder about the $amount'
      '$what. Could you send it$by? Thank you!';
}

/// "Concert tickets" reads "concert tickets" mid-sentence; "GCash load"
/// and "BPI" keep their capitals.
String _midSentence(String s) => s.length > 1 && s[1] != s[1].toUpperCase()
    ? '${s[0].toLowerCase()}${s.substring(1)}'
    : s;
