import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

/// Net worth front and centre, with this month's money in and out under it.
/// The total counts up when it first appears and whenever it changes.
class BalanceHero extends StatelessWidget {
  const BalanceHero({
    super.key,
    required this.netWorthMinor,
    required this.currency,
    required this.accountCount,
    required this.incomeMinor,
    required this.spentMinor,
    required this.hidden,
  });

  final int netWorthMinor;
  final Currency currency;
  final int accountCount;
  final int incomeMinor;
  final int spentMinor;
  final bool hidden;

  String _amount(int minor) =>
      hidden ? '${currency.symbol} ••••••' : Money.format(minor, currency);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET WORTH',
            style: text.labelMedium?.copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: hidden
                ? 'Net worth hidden'
                : 'Net worth ${Money.format(netWorthMinor, currency)}',
            excludeSemantics: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: netWorthMinor.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _amount(v.round()),
                  style: text.displaySmall?.copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across $accountCount '
            '${accountCount == 1 ? 'account' : 'accounts'} · '
            '${currency.code}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 18),
          Text(
            'THIS MONTH',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Flow(
                  label: 'Income',
                  amount: _amount(incomeMinor),
                  icon: Icons.south_west_rounded,
                  color: AppColors.leafBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Flow(
                  label: 'Spending',
                  amount: _amount(spentMinor),
                  icon: Icons.north_east_rounded,
                  color: AppColors.ember,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium?.copyWith(fontSize: 11)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: text.titleMedium?.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
