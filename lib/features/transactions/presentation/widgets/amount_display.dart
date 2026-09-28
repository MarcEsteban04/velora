import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/amount_expression.dart';

/// The amount row: a currency pill on the left and the big number centred.
///
/// - A plain number shows grouped, as typed (a trailing "." stays visible).
/// - With an operator, the expression moves to a small line above and the
///   big number shows the live result.
/// - [hint] (for example "Pick a category") sits underneath once there's an
///   amount.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.expression,
    required this.currency,
    required this.color,
    required this.onCurrencyTap,
    required this.onAmountTap,
    this.hint,
  });

  final AmountExpression expression;
  final Currency currency;
  final Color color;
  final VoidCallback onCurrencyTap;
  final VoidCallback onAmountTap;
  final String? hint;

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
    final result = expression.evaluate(decimalDigits: currency.decimalDigits);
    final big = hasOp
        ? Money.format(result, currency).replaceFirst(currency.symbol, '')
        : _groupTyped(expression.text);
    final empty = expression.isEmpty;

    return SizedBox(
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
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Currency ${currency.code}. Change account',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onCurrencyTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surface.withValues(alpha: 0.7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency.symbol,
                          style: text.titleMedium?.copyWith(color: color),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: 'Amount ${Money.format(result, currency)}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onAmountTap,
                    behavior: HitTestBehavior.opaque,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(big),
                        tween: Tween(begin: 1.05, end: 1),
                        duration: const Duration(milliseconds: 150),
                        builder: (context, s, child) =>
                            Transform.scale(scale: s, child: child),
                        child: Text(
                          hasOp ? '= $big' : big,
                          style: text.displaySmall?.copyWith(
                            fontSize: 58,
                            color: empty
                                ? AppColors.textMuted.withValues(alpha: 0.45)
                                : color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Balances the currency pill so the amount stays centred.
              const SizedBox(width: 64),
            ],
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hint == null || empty ? 0 : 1,
            child: Text(
              hint ?? '',
              style: text.labelMedium?.copyWith(color: AppColors.ember),
            ),
          ),
        ],
      ),
    );
  }
}
