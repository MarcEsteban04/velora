import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/amount_expression.dart';

/// The big amount at the top of the entry screen.
///
/// While the user types a plain number, it's shown grouped as typed (a
/// trailing "." stays visible). Once there's an operator, the expression
/// moves to a small line above and the big line shows the live result.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.expression,
    required this.currency,
    required this.color,
  });

  final AmountExpression expression;
  final Currency currency;
  final Color color;

  static final _grouping = NumberFormat('#,##0', 'en_US');

  static String _groupTyped(String number) {
    if (number.isEmpty) return '0';
    final dot = number.indexOf('.');
    final whole = dot == -1 ? number : number.substring(0, dot);
    final grouped = _grouping.format(
      int.tryParse(whole.isEmpty ? '0' : whole) ?? 0,
    );
    return dot == -1 ? grouped : '$grouped${number.substring(dot)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasOp = expression.hasOperator;
    final big = hasOp
        ? Money.format(
            expression.evaluate(decimalDigits: currency.decimalDigits),
            currency,
          )
        : '${currency.symbol}${_groupTyped(expression.text)}';
    final empty = expression.isEmpty;

    return Semantics(
      liveRegion: true,
      label: 'Amount $big',
      excludeSemantics: true,
      child: SizedBox(
        height: 112,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: hasOp ? 1 : 0,
              child: Text(
                expression.text.replaceAllMapped(
                  RegExp('[+−×÷]'),
                  (m) => ' ${m[0]} ',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: text.displaySmall!.copyWith(
                  fontSize: 56,
                  color: empty
                      ? AppColors.textMuted.withValues(alpha: 0.6)
                      : color,
                ),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(big),
                  tween: Tween(begin: 1.06, end: 1),
                  duration: const Duration(milliseconds: 160),
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Text(hasOp ? '= $big' : big),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
