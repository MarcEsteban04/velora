import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/flame.dart';

/// Each flame colour: a bright core at the base and a deeper tip, and a
/// darker tip for the light scenes so it keeps its contrast.
extension FlameColors on FlameTier {
  (Color core, Color tip, Color tipLight) get _shades => switch (this) {
    FlameTier.spark => (
      const Color(0xFFFFD58A),
      const Color(0xFFF0A15E),
      const Color(0xFFD1701F),
    ),
    FlameTier.amber => (
      const Color(0xFFFFD05A),
      const Color(0xFFFF8A2E),
      const Color(0xFFCB5E10),
    ),
    FlameTier.redHot => (
      const Color(0xFFFFB84A),
      const Color(0xFFF2452E),
      const Color(0xFFC8321C),
    ),
    FlameTier.magenta => (
      const Color(0xFFFFA58A),
      const Color(0xFFE8336B),
      const Color(0xFFC21F55),
    ),
    FlameTier.violet => (
      const Color(0xFFF5B8FF),
      const Color(0xFFA45CFF),
      const Color(0xFF7B3BE0),
    ),
    FlameTier.blue => (
      const Color(0xFFBDF2FF),
      const Color(0xFF3F86FF),
      const Color(0xFF2360D8),
    ),
    FlameTier.whiteHot => (
      const Color(0xFFFFFFFF),
      const Color(0xFF8FE6FF),
      const Color(0xFF1C9FC9),
    ),
    FlameTier.golden => (
      const Color(0xFFFFF6C2),
      const Color(0xFFF2B705),
      const Color(0xFFB88300),
    ),
    FlameTier.legendary => (
      const Color(0xFFFFFFFF),
      const Color(0xFFFF6FAE),
      const Color(0xFFD13F80),
    ),
  };

  /// The flame's main colour, for tints, rings and text.
  Color get tint => AppColors.isLight ? _shades.$3 : _shades.$2;

  /// The bright base of the flame.
  Color get core => AppColors.isLight
      ? Color.lerp(_shades.$3, Colors.white, 0.45)!
      : _shades.$1;
}

/// The rainbow the legendary flame cycles through.
const _rainbowColors = [
  Color(0xFFFF5E5E),
  Color(0xFFFFB23D),
  Color(0xFFFFE14D),
  Color(0xFF6CBF78),
  Color(0xFF4FA3FF),
  Color(0xFFB07CFF),
  Color(0xFFFF5E5E),
];

/// A flame filled with its tier's colours: core at the base, tip at the
/// top. The legendary one slowly turns through the rainbow. [dim] draws it
/// grey, for a streak that's out or a badge not earned yet.
class FlameIcon extends StatefulWidget {
  const FlameIcon({
    super.key,
    required this.tier,
    this.size = 24,
    this.outlined = false,
    this.dim = false,
  });

  final FlameTier tier;
  final double size;

  /// The outline flame, for a today that's still open.
  final bool outlined;
  final bool dim;

  @override
  State<FlameIcon> createState() => _FlameIconState();
}

class _FlameIconState extends State<FlameIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  bool get _isRainbow => widget.tier == FlameTier.legendary && !widget.dim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FlameIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final move = _isRainbow && !MediaQuery.disableAnimationsOf(context);
    if (move && _spin == null) {
      _spin = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    } else if (!move && _spin != null) {
      _spin!.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.outlined
          ? Icons.local_fire_department_outlined
          : Icons.local_fire_department_rounded,
      size: widget.size,
      color: Colors.white,
    );
    if (widget.dim) {
      return Icon(icon.icon, size: widget.size, color: AppColors.textMuted);
    }
    Shader shader(Rect r, double turn) {
      if (_isRainbow) {
        return SweepGradient(
          colors: _rainbowColors,
          transform: GradientRotation(turn * math.pi * 2),
        ).createShader(r);
      }
      return LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [widget.tier.core, widget.tier.tint],
        stops: const [0.12, 0.8],
      ).createShader(r);
    }

    Widget masked(double turn) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => shader(r, turn),
      child: icon,
    );

    final spin = _spin;
    if (spin == null) return masked(0);
    return AnimatedBuilder(
      animation: spin,
      builder: (_, _) => masked(spin.value),
    );
  }
}
