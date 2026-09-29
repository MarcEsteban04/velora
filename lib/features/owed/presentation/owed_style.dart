import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/owed.dart';

/// Colours for people's initials, picked by name so each keeps theirs.
List<Color> get _palette => [
  AppColors.leafBright,
  AppColors.sky,
  AppColors.lilac,
  AppColors.ember,
];

extension OwedStyle on Owed {
  Color get color =>
      _palette[name.trim().toLowerCase().codeUnits.fold(0, (s, c) => s + c) %
          _palette.length];

  /// "J" for Juan, "MS" for Maria Santos.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }
}

/// A person's initials in a tinted circle; a check once they're settled.
class OwedAvatar extends StatelessWidget {
  const OwedAvatar({
    super.key,
    required this.owed,
    this.size = 42,
    this.settled = false,
  });

  final Owed owed;
  final double size;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final color = owed.color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: settled
          ? Icon(Icons.check_rounded, size: size * 0.5, color: color)
          : Text(
              owed.initials,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: size * 0.36, color: color),
            ),
    );
  }
}

/// "Pay back by Oct 15", "Pay back today", "Overdue since Oct 15".
String payBackLabel(DateTime due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
  final day = DateFormat('MMM d').format(due);
  return switch (days) {
    < 0 => 'Overdue since $day',
    0 => 'Pay back today',
    1 => 'Pay back tomorrow',
    _ => 'Pay back by $day',
  };
}

/// The line under someone: what it was for, and when it's due back.
String owedOutlook(OwedProgress p, DateTime now) {
  if (p.isSettled) return 'Paid back in full';
  final c = Currencies.byCode(p.owed.currencyCode);
  return [
    if (p.owed.note case final n? when n.isNotEmpty) n,
    if (p.owed.dueOn case final d?) payBackLabel(d, now),
    if (p.backMinor > 0) '${Money.short(p.backMinor, c)} back',
  ].join(' · ');
}
