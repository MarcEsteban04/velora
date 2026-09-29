import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/debt.dart';

extension DebtKindStyle on DebtKind {
  IconData get icon => switch (this) {
    DebtKind.card => Icons.credit_card_rounded,
    DebtKind.bnpl => Icons.shopping_bag_rounded,
    DebtKind.loan => Icons.account_balance_rounded,
    DebtKind.personal => Icons.handshake_rounded,
  };

  Color get color => switch (this) {
    DebtKind.card => AppColors.sky,
    DebtKind.bnpl => AppColors.ember,
    DebtKind.loan => AppColors.lilac,
    DebtKind.personal => AppColors.leafBright,
  };
}

/// Quick starts for the empty state: a name and a kind.
const debtTemplates = <(String, DebtKind)>[
  ('Credit card', DebtKind.card),
  ('BillEase', DebtKind.bnpl),
  ('SPayLater', DebtKind.bnpl),
  ('Loan', DebtKind.loan),
  ('Borrowed from a friend', DebtKind.personal),
];

/// "Due Oct 5", "Due today", "Due tomorrow".
String dueLabel(DateTime due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = due.difference(today).inDays;
  return switch (days) {
    0 => 'Due today',
    1 => 'Due tomorrow',
    _ => 'Due ${DateFormat('MMM d').format(due)}',
  };
}

/// The one-line outlook under a debt: when it's due, the usual payment and
/// how long to go.
String debtOutlook(DebtProgress p, DateTime now) {
  if (p.isPaidOff) return 'Paid off';
  final c = Currencies.byCode(p.debt.currencyCode);
  return [
    if (p.nextDue case final d?) dueLabel(d, now),
    if (p.debt.monthlyMinor case final m?) '${Money.short(m, c)}/mo',
    if (p.monthsLeft case final n?)
      n == 1 ? 'last payment' : 'about $n months left',
  ].join(' · ');
}

/// "1st", "2nd", "23rd".
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}
