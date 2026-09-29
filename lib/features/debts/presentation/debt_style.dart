import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/presentation/institutions.dart';
import '../../accounts/presentation/widgets/institution_logo.dart';
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

extension DebtBrand on Debt {
  /// The lender's brand, recognised from the name (BillEase, SPayLater,
  /// "BPI credit card").
  Institution? get institution => Institutions.forDebt(name);

  /// The brand's colour when there is one, else the kind's.
  Color get color => institution?.gradient.first ?? kind.color;
}

/// A debt's badge: the lender's logo on its plate when it has one, else
/// the kind's icon in a tinted square. [size] is the square's side; a logo
/// takes the same height and a wider plate.
class DebtBadge extends StatelessWidget {
  const DebtBadge({
    super.key,
    required this.debt,
    this.size = 42,
    this.paidOff = false,
  });

  final Debt debt;
  final double size;
  final bool paidOff;

  @override
  Widget build(BuildContext context) {
    final brand = debt.institution;
    if (brand != null && !paidOff) {
      return InstitutionLogo(
        institution: brand,
        height: size * 0.72,
        width: size * 1.6,
      );
    }
    final color = debt.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(
        paidOff ? Icons.celebration_rounded : debt.kind.icon,
        size: size * 0.5,
        color: color,
      ),
    );
  }
}

/// Quick starts for the empty state: a name and a kind.
const debtTemplates = <(String, DebtKind)>[
  ('Credit card', DebtKind.card),
  ('BillEase', DebtKind.bnpl),
  ('SPayLater', DebtKind.bnpl),
  ('Loan', DebtKind.loan),
  ('Borrowed from a friend', DebtKind.personal),
];

/// "Due Oct 5", "Due today", "Due tomorrow", "Overdue since Oct 5".
String dueLabel(DateTime due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
  return switch (days) {
    < 0 => 'Overdue since ${DateFormat('MMM d').format(due)}',
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
    if (p.availableMinor case final a?) '${Money.short(a, c)} available',
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
