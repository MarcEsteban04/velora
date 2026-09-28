import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';

/// This month at a glance: money in and money out. Net worth lives in the
/// Wallet tab; Home stays about what's happening now.
class MonthGlance extends StatelessWidget {
  const MonthGlance({
    super.key,
    required this.currency,
    required this.incomeMinor,
    required this.spentMinor,
    required this.hidden,
  });

  final Currency currency;
  final int incomeMinor;
  final int spentMinor;
  final bool hidden;

  String _amount(int minor) =>
      hidden ? '${currency.symbol} ••••••' : Money.format(minor, currency);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'THIS MONTH',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
        ),
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
