import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The calculator panel that floats over the bottom of the entry screen:
///
///   ⌫  AC  %  ÷
///   7  8   9  ×
///   4  5   6  −
///   1  2   3  +
///   00 0   .  =
///
/// Delete and clear are red, operators green, and "=" is solid green. The
/// handle at the bottom hides the panel to reveal the rest of the form.
class CalcKeypad extends StatelessWidget {
  const CalcKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onPercent,
    required this.onEquals,
    required this.onHide,
    this.allowDecimal = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onPercent;
  final VoidCallback onEquals;
  final VoidCallback onHide;
  final bool allowDecimal;

  static const _danger = Color(0xFFF0766E);

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.textTheme.headlineSmall!.copyWith(fontSize: 26);

    Widget digit(String d, {String? spoken}) => _Key(
      label: spoken ?? d,
      onTap: () => onDigit(d),
      child: Text(d, style: style),
    );
    Widget op(String o, String spoken) => _Key(
      label: spoken,
      tone: _Tone.accent,
      onTap: () => onOperator(o),
      child: Text(o, style: style.copyWith(color: AppColors.leafBright)),
    );

    final rows = <List<Widget>>[
      [
        _Key(
          label: 'delete, hold to clear',
          tone: _Tone.danger,
          onTap: onBackspace,
          onLongPress: onClear,
          child: const Icon(Icons.backspace_rounded, color: _danger),
        ),
        _Key(
          label: 'clear',
          tone: _Tone.danger,
          onTap: onClear,
          child: Text('AC', style: style.copyWith(color: _danger)),
        ),
        _Key(
          label: 'percent',
          tone: _Tone.accent,
          onTap: onPercent,
          child: Text('%', style: style.copyWith(color: AppColors.leafBright)),
        ),
        op('÷', 'divide'),
      ],
      [digit('7'), digit('8'), digit('9'), op('×', 'times')],
      [digit('4'), digit('5'), digit('6'), op('−', 'minus')],
      [digit('1'), digit('2'), digit('3'), op('+', 'plus')],
      [
        _Key(
          label: 'double zero',
          onTap: () {
            onDigit('0');
            onDigit('0');
          },
          child: Text('00', style: style),
        ),
        digit('0'),
        _Key(
          label: 'decimal point',
          enabled: allowDecimal,
          onTap: onDecimal,
          child: Text('.', style: style),
        ),
        _Key(
          label: 'equals',
          tone: _Tone.solid,
          onTap: onEquals,
          child: Text('=', style: style.copyWith(color: AppColors.textPrimary)),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
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
          Semantics(
            button: true,
            label: 'Hide calculator',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onHide,
              radius: 28,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.keyboard_hide_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { plain, accent, danger, solid }

class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.tone = _Tone.plain,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final _Tone tone;
  final bool enabled;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  Color get _fill => switch (widget.tone) {
    _Tone.plain => AppColors.night.withValues(alpha: 0.85),
    _Tone.accent => AppColors.leaf.withValues(alpha: 0.18),
    _Tone.danger => const Color(0xFF4A1F24),
    _Tone.solid => AppColors.leaf,
  };

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedScale(
            scale: _down ? 0.94 : 1,
            duration: const Duration(milliseconds: 80),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: _down
                    ? Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.08),
                        _fill,
                      )
                    : _fill,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
