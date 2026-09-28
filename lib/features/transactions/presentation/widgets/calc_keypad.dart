import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Digits, a decimal point, delete (long-press clears) and the four
/// operators, in one compact grid within easy thumb reach.
class CalcKeypad extends StatelessWidget {
  const CalcKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.accent,
    this.allowDecimal = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final Color accent;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
      label: d,
      onTap: () => onDigit(d),
      child: Text(d, style: _digitStyle),
    );
    Widget op(String o, String spoken) => _Key(
      label: spoken,
      tint: accent,
      onTap: () => onOperator(o),
      child: Text(o, style: _digitStyle.copyWith(color: accent)),
    );

    final rows = <List<Widget>>[
      [digit('7'), digit('8'), digit('9'), op('÷', 'divide')],
      [digit('4'), digit('5'), digit('6'), op('×', 'times')],
      [digit('1'), digit('2'), digit('3'), op('−', 'minus')],
      [
        _Key(
          label: 'decimal point',
          enabled: allowDecimal,
          onTap: onDecimal,
          child: Text('.', style: _digitStyle),
        ),
        digit('0'),
        _Key(
          label: 'delete, hold to clear',
          onTap: onBackspace,
          onLongPress: onClear,
          child: const Icon(
            Icons.backspace_rounded,
            color: AppColors.textSecondary,
          ),
        ),
        op('+', 'plus'),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final (i, key) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: key),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static final _digitStyle = AppTypography.textTheme.headlineSmall!.copyWith(
    fontSize: 24,
  );
}

class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.tint,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final Color? tint;
  final bool enabled;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.tint;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1 : 0.35,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _down
                  ? (base ?? AppColors.leaf).withValues(alpha: 0.3)
                  : base != null
                  ? base.withValues(alpha: 0.12)
                  : AppColors.surface.withValues(alpha: 0.75),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
