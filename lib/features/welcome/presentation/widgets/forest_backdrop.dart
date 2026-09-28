import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// An animated bamboo forest drawn entirely in code: canopy light, swaying
/// stalks, drifting pollen and falling leaves.
///
/// It uses a single looping controller, and every motion completes a whole
/// number of cycles per loop, so the loop is seamless. It holds still when
/// the OS "reduce motion" setting is on.
class ForestBackdrop extends StatefulWidget {
  const ForestBackdrop({super.key});

  @override
  State<ForestBackdrop> createState() => _ForestBackdropState();
}

class _ForestBackdropState extends State<ForestBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ForestPainter(_controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Stalk {
  const _Stalk(this.x, this.width, this.phase, {this.leafy = true});
  final double x; // Fraction of the screen width.
  final double width;
  final double phase;
  final bool leafy;
}

class _Particle {
  _Particle(math.Random r)
    : x = r.nextDouble(),
      y = r.nextDouble(),
      radius = 1 + r.nextDouble() * 2.4,
      speed = 1 + r.nextInt(2).toDouble(),
      phase = r.nextDouble() * math.pi * 2;
  final double x, y, radius, speed, phase;
}

class _FallingLeaf {
  _FallingLeaf(math.Random r)
    : x = r.nextDouble(),
      offset = r.nextDouble(),
      size = 9 + r.nextDouble() * 8,
      spin = (r.nextBool() ? 1 : -1) * (1 + r.nextInt(2)).toDouble(),
      phase = r.nextDouble() * math.pi * 2;
  final double x, offset, size, spin, phase;
}

class _ForestPainter extends CustomPainter {
  _ForestPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const _tau = math.pi * 2;

  static const _backStalks = [
    _Stalk(0.10, 14, 0.0),
    _Stalk(0.24, 10, 1.3, leafy: false),
    _Stalk(0.72, 12, 2.1),
    _Stalk(0.84, 9, 0.7, leafy: false),
    _Stalk(0.95, 13, 2.8),
  ];

  static const _frontStalks = [
    _Stalk(-0.01, 26, 0.4),
    _Stalk(0.07, 18, 1.9),
    _Stalk(0.93, 22, 1.1),
    _Stalk(1.02, 28, 2.5),
  ];

  // A fixed seed keeps the scene identical on every launch.
  static final _rng = math.Random(7);
  static final _pollen = List.generate(34, (_) => _Particle(_rng));
  static final _leaves = List.generate(7, (_) => _FallingLeaf(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rect = Offset.zero & size;

    _paintSky(canvas, rect);
    _paintLightRays(canvas, size, t);
    for (final s in _backStalks) {
      _paintStalk(
        canvas,
        size,
        s,
        t,
        color: AppColors.forestMist.withValues(alpha: 0.16),
        sway: 0.010,
      );
    }
    _paintPollen(canvas, size, t);
    for (final s in _frontStalks) {
      _paintStalk(
        canvas,
        size,
        s,
        t,
        color: AppColors.forestNight.withValues(alpha: 0.82),
        sway: 0.006,
      );
    }
    _paintFallingLeaves(canvas, size, t);
    _paintGroundFade(canvas, rect);
  }

  void _paintSky(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.forestCanopy,
            AppColors.forestMid,
            AppColors.forestDeep,
            AppColors.forestNight,
          ],
          stops: [0, 0.35, 0.68, 1],
        ).createShader(rect),
    );

    // Sun breaking through the canopy.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.72),
          radius: 0.9,
          colors: [
            const Color(0xFFD9F2B5).withValues(alpha: 0.30),
            const Color(0xFFF0A15E).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  void _paintLightRays(Canvas canvas, Size size, double t) {
    const rays = [(0.30, 0.10, 0.0), (0.52, 0.14, 2.0), (0.70, 0.08, 4.0)];
    for (final (x, spread, phase) in rays) {
      final shimmer = 0.5 + 0.5 * math.sin(t * _tau * 2 + phase);
      final top = size.width * x;
      final path = Path()
        ..moveTo(top - 6, 0)
        ..lineTo(top + 6, 0)
        ..lineTo(
          top + size.width * spread - size.width * 0.10,
          size.height * 0.75,
        )
        ..lineTo(
          top - size.width * spread - size.width * 0.10,
          size.height * 0.75,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.05 + 0.05 * shimmer),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  void _paintStalk(
    Canvas canvas,
    Size size,
    _Stalk s,
    double t, {
    required Color color,
    required double sway,
  }) {
    final base = Offset(size.width * s.x, size.height + 10);
    final angle = math.sin(t * _tau * 3 + s.phase) * sway;
    final height = size.height * 1.15;
    final paint = Paint()..color = color;

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-s.width / 2, -height, s.width, height),
        Radius.circular(s.width / 2),
      ),
      paint,
    );

    // Nodes (rings) and leaf sprays.
    final nodeGap = size.height * 0.13;
    final nodePaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.55)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    var i = 0;
    for (var y = -nodeGap * 0.6; y > -height; y -= nodeGap, i++) {
      canvas.drawLine(
        Offset(-s.width / 2 - 1.5, y),
        Offset(s.width / 2 + 1.5, y),
        nodePaint,
      );
      if (s.leafy && i.isOdd) {
        final right = (i ~/ 2).isEven;
        final flutter = math.sin(t * _tau * 4 + s.phase + i) * 0.08;
        for (var k = 0; k < 3; k++) {
          // Leaves droop outward; the left side mirrors the right.
          final droop = 0.05 + k * 0.32 + flutter;
          _drawLeaf(
            canvas,
            Offset((right ? 1 : -1) * s.width / 2, y),
            length: s.width * 3.2 + k * 6,
            angle: right ? droop : math.pi - droop,
            paint: paint,
          );
        }
      }
    }
    canvas.restore();
  }

  void _drawLeaf(
    Canvas canvas,
    Offset at, {
    required double length,
    required double angle,
    required Paint paint,
  }) {
    final w = length * 0.22;
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.45, -w, length, 0)
      ..quadraticBezierTo(length * 0.45, w, 0, 0)
      ..close();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  void _paintPollen(Canvas canvas, Size size, double t) {
    for (final p in _pollen) {
      final y = ((p.y - t * p.speed) % 1.0) * size.height;
      final x = (p.x + math.sin(t * _tau * 2 + p.phase) * 0.015) * size.width;
      final twinkle = 0.45 + 0.55 * math.sin(t * _tau * 5 + p.phase).abs();
      final glow = Paint()
        ..color = AppColors.ember.withValues(alpha: 0.35 * twinkle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 2.2);
      canvas.drawCircle(Offset(x, y), p.radius * 1.8, glow);
      canvas.drawCircle(
        Offset(x, y),
        p.radius * 0.6,
        Paint()..color = AppColors.cream.withValues(alpha: 0.8 * twinkle),
      );
    }
  }

  void _paintFallingLeaves(Canvas canvas, Size size, double t) {
    final paint = Paint()..color = AppColors.leaf.withValues(alpha: 0.55);
    for (final l in _leaves) {
      final progress = (t * 2 + l.offset) % 1.0;
      final y = -30 + progress * (size.height + 60);
      final x =
          (l.x + math.sin(progress * _tau * 2 + l.phase) * 0.06) * size.width;
      _drawLeaf(
        canvas,
        Offset(x, y),
        length: l.size * 2,
        angle: progress * _tau * l.spin + l.phase,
        paint: paint,
      );
    }
  }

  void _paintGroundFade(Canvas canvas, Rect rect) {
    // Darkens the lower half so the call-to-action stays readable.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.forestNight.withValues(alpha: 0.55),
            AppColors.forestNight.withValues(alpha: 0.95),
          ],
          stops: const [0.45, 0.72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ForestPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
