import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A one-shot confetti burst from the top center, pulled down by gravity.
/// It draws nothing when "reduce motion" is on.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reduceMotion && _controller.isDismissed) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(_controller),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
    : angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9,
      speed = 0.55 + r.nextDouble() * 0.65,
      spin = (r.nextDouble() - 0.5) * 18,
      width = 6 + r.nextDouble() * 6,
      colorIndex = r.nextInt(6);

  /// Read live, so confetti matches the current scene.
  static List<Color> get colors => [
    AppColors.leafBright,
    AppColors.ember,
    AppColors.cream,
    AppColors.sky,
    AppColors.lilac,
    AppColors.rust,
  ];

  final double angle, speed, spin, width;
  final int colorIndex;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;
  static final _rng = math.Random(5);
  static final _pieces = List.generate(70, (_) => _Piece(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t == 0 || t == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.18);
    final scale = size.height;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;

    for (final p in _pieces) {
      final v = p.speed * scale;
      final dx = math.cos(p.angle) * v * t;
      final dy = math.sin(p.angle) * v * t + 0.9 * scale * t * t;
      final paint = Paint()
        ..color = _Piece.colors[p.colorIndex].withValues(alpha: fade);
      canvas
        ..save()
        ..translate(origin.dx + dx, origin.dy + dy)
        ..rotate(p.spin * t)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.width,
              height: p.width * 0.45,
            ),
            const Radius.circular(2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
