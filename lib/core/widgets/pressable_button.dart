import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

enum PressableButtonVariant { primary, light }

/// A tactile, "physical" button. The face sits on a darker lip and sinks into
/// it when pressed. It supports keyboard/switch activation, screen readers
/// and a disabled state.
class PressableButton extends StatefulWidget {
  const PressableButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PressableButtonVariant.primary,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PressableButtonVariant variant;
  final double height;

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  static const _depth = 6.0;
  static const _radius = 22.0;

  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
    if (value) HapticFeedback.lightImpact();
  }

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(widget.variant);
    final labelStyle = Theme.of(context).textTheme.titleMedium!
        .copyWith(color: palette.foreground);
    final offset = _pressed ? _depth : 0.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activate(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _enabled ? widget.onPressed : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _enabled ? 1 : 0.5,
            child: SizedBox(
              height: widget.height + _depth,
              child: Stack(
                children: [
                  // The lip the face presses down into.
                  Positioned.fill(
                    top: _depth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.lip,
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    left: 0,
                    right: 0,
                    top: offset,
                    height: widget.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_radius),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [palette.faceTop, palette.faceBottom],
                        ),
                        border: Border.all(
                          color: _focused ? AppColors.ember : palette.highlight,
                          width: _focused ? 2.5 : 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: palette.foreground,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.faceTop,
    required this.faceBottom,
    required this.lip,
    required this.highlight,
    required this.foreground,
  });

  factory _Palette.of(PressableButtonVariant variant) => switch (variant) {
    PressableButtonVariant.primary => const _Palette(
      faceTop: AppColors.leafBright,
      faceBottom: AppColors.leaf,
      lip: AppColors.leafShadow,
      highlight: Color(0x33FFFFFF),
      foreground: AppColors.textPrimary,
    ),
    PressableButtonVariant.light => const _Palette(
      faceTop: Colors.white,
      faceBottom: AppColors.cream,
      lip: Color(0xFFCDBBA5),
      highlight: Color(0x66FFFFFF),
      foreground: AppColors.textOnLight,
    ),
  };

  final Color faceTop;
  final Color faceBottom;
  final Color lip;
  final Color highlight;
  final Color foreground;
}
