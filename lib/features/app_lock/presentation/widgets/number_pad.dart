import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A calm, phone-style keypad for entering a PIN. Keys are large (72pt) for
/// easy thumb reach, give a light haptic tap, and work with screen readers.
class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
      label: d,
      semanticLabel: d,
      enabled: enabled,
      onTap: () => onDigit(d),
      child: Text(
        d,
        style: AppTypography.textTheme.displaySmall?.copyWith(fontSize: 28),
      ),
    );

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final d in row) digit(d)],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reserved for biometric unlock.
              const SizedBox.square(dimension: _Key.size),
              digit('0'),
              _Key(
                label: '',
                semanticLabel: 'Delete last digit',
                enabled: enabled,
                filled: false,
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_rounded,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    required this.enabled,
    this.filled = true,
  });

  static const size = 72.0;

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool enabled;
  final bool filled;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _Key.size,
            height: _Key.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !widget.filled
                  ? Colors.transparent
                  : _down
                  ? AppColors.leaf.withValues(alpha: 0.35)
                  : AppColors.surface.withValues(alpha: 0.6),
              border: widget.filled
                  ? Border.all(color: AppColors.hairline(0.08))
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
