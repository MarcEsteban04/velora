import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The animated Himalayan valley behind Velora, drawn entirely in code:
/// layered ridges with a pine line, drifting mist, rising embers and falling
/// autumn leaves.
///
/// - Night: twinkling stars, a glowing moon and the odd shooting star.
/// - Day: a sun with slow rays and drifting clouds.
/// - Afternoon: golden hour. A big low sun sinking behind the far peaks,
///   long beams, sunlit clouds and a few birds heading home.
///
/// Colours come from the active palette, so it follows the appearance
/// setting.
///
/// It uses a single looping controller, and every motion completes a whole
/// number of cycles per loop, so the loop is seamless. It holds still when
/// the OS "reduce motion" setting is on.
class DuskBackdrop extends StatefulWidget {
  const DuskBackdrop({super.key, this.showMoon = true});

  /// Content-heavy screens hide the moon so it never sits behind text.
  final bool showMoon;

  @override
  State<DuskBackdrop> createState() => _DuskBackdropState();
}

class _DuskBackdropState extends State<DuskBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
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
        painter: _DuskPainter(
          _controller,
          showMoon: widget.showMoon,
          scene: AppColors.scene,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// A mountain ridge profile. [baseline] and [amplitude] are fractions of the
/// screen height, and each wave is `(frequency, phase, weight)`. Waves use
/// `1 - |sin|`, which gives pointed peaks instead of rolling hills.
class _Ridge {
  const _Ridge(this.baseline, this.amplitude, this.waves);

  final double baseline;
  final double amplitude;
  final List<(double, double, double)> waves;

  double yAt(double nx, Size size) {
    var h = 0.0;
    for (final (freq, phase, weight) in waves) {
      h += (1 - math.sin(nx * freq * math.pi + phase).abs()) * weight;
    }
    return size.height * (baseline - h * amplitude);
  }

  Path path(Size size) {
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 3; x += 3) {
      path.lineTo(x, yAt(x / size.width, size));
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }
}

class _Star {
  _Star(math.Random r)
    : x = r.nextDouble(),
      y = math.pow(r.nextDouble(), 1.6) * 0.36,
      radius = 0.5 + r.nextDouble() * 1.3,
      speed = 1 + r.nextInt(4).toDouble(),
      phase = r.nextDouble() * math.pi * 2;
  final double x, y, radius, speed, phase;
}

class _Ember {
  _Ember(math.Random r)
    : x = r.nextDouble(),
      y = r.nextDouble(),
      radius = 1 + r.nextDouble() * 2.2,
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
      phase = r.nextDouble() * math.pi * 2,
      warm = r.nextBool();
  final double x, offset, size, spin, phase;
  final bool warm;
}

class _DuskPainter extends CustomPainter {
  _DuskPainter(this.animation, {required this.showMoon, required this.scene})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool showMoon;

  /// Picks the sky's cast (sun, moon, stars, clouds, birds). Colours come
  /// from the active palette.
  final Scene scene;

  bool get _light => scene != Scene.night;

  static const _tau = math.pi * 2;

  static const _far = _Ridge(0.40, 0.08, [
    (1.3, 0.4, 0.6),
    (3.1, 1.7, 0.3),
    (7.0, 0.2, 0.1),
  ]);
  static const _mid = _Ridge(0.49, 0.07, [
    (1.8, 2.2, 0.5),
    (4.3, 0.9, 0.35),
    (9.0, 1.1, 0.15),
  ]);
  static const _near = _Ridge(0.57, 0.05, [
    (1.1, 4.0, 0.6),
    (2.9, 2.5, 0.3),
    (6.0, 0.3, 0.1),
  ]);

  // A fixed seed keeps the scene identical on every launch.
  static final _rng = math.Random(11);
  static final _stars = List.generate(70, (_) => _Star(_rng));
  static final _embers = List.generate(26, (_) => _Ember(_rng));
  static final _leaves = List.generate(7, (_) => _FallingLeaf(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rect = Offset.zero & size;

    _paintSky(canvas, rect);
    switch (scene) {
      case Scene.day:
        if (showMoon) _paintSun(canvas, size, t);
        _paintClouds(canvas, size, t);
      case Scene.afternoon:
        // Drawn before the ridges, so the peaks hide the sun's lower edge.
        _paintLowSun(canvas, size, t, disc: showMoon);
        _paintClouds(canvas, size, t, golden: true);
        _paintBirds(canvas, size, t);
      case Scene.night:
        _paintStars(canvas, size, t);
        _paintShootingStar(canvas, size, t);
        if (showMoon) _paintMoon(canvas, size, t);
    }

    _paintRidge(
      canvas,
      size,
      _far,
      top: AppColors.ridgeFarTop,
      base: AppColors.ridgeFarBase,
    );
    _paintMist(canvas, size, t, y: 0.43, speed: 1, alpha: _light ? 0.3 : 0.10);
    _paintRidge(
      canvas,
      size,
      _mid,
      top: AppColors.ridgeMidTop,
      base: AppColors.ridgeMidBase,
    );
    _paintMist(
      canvas,
      size,
      t,
      y: 0.52,
      speed: -1,
      alpha: _light ? 0.24 : 0.08,
    );
    _paintRidge(
      canvas,
      size,
      _near,
      top: AppColors.ridgeNear,
      base: AppColors.night,
    );
    _paintPines(canvas, size);

    _paintEmbers(canvas, size, t);
    _paintFallingLeaves(canvas, size, t);
    _paintGroundFade(canvas, rect);
  }

  void _paintSky(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.skyZenith,
            AppColors.skyIndigo,
            AppColors.skyPlum,
            AppColors.skyRose,
            AppColors.skyAmber,
          ],
          stops: [0, 0.16, 0.28, 0.36, 0.44],
        ).createShader(rect),
    );

    // Warm glow rising off the horizon, behind the mascot.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 0.75,
          colors: [
            AppColors.skyAmber.withValues(alpha: 0.35),
            AppColors.skyRose.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  void _paintStars(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final s in _stars) {
      final twinkle =
          0.35 + 0.65 * math.sin(t * _tau * s.speed * 3 + s.phase).abs();
      // Stars fade out as they near the bright horizon.
      final fade = 1 - (s.y / 0.36);
      paint.color = AppColors.moon.withValues(alpha: 0.9 * twinkle * fade);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  void _paintShootingStar(Canvas canvas, Size size, double t) {
    // Twice per loop, a streak crosses the upper sky for a brief moment.
    const window = 0.05;
    final s = (t * 2) % 1.0;
    if (s > window) return;
    final p = Curves.easeOut.transform(s / window);
    final start = Offset(size.width * 0.86, size.height * 0.05);
    final travel = Offset(-size.width * 0.42, size.height * 0.14);
    final head = start + travel * p;
    final tail = head - travel * 0.35;
    final opacity = math.sin(p * math.pi);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.moon.withValues(alpha: 0.9 * opacity),
          ],
        ).createShader(Rect.fromPoints(tail, head)),
    );
  }

  void _paintSun(Canvas canvas, Size size, double t) {
    final center = Offset(size.width * 0.18, size.height * 0.11);
    final radius = size.width * 0.085;
    final pulse = 0.9 + 0.1 * math.sin(t * _tau * 2);

    // Soft rays, turning very slowly.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * _tau);
    final ray = Paint()
      ..color = AppColors.moon.withValues(alpha: 0.35 * pulse)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * _tau / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(dir * radius * 1.35, dir * radius * 1.75, ray);
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius * 3.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.moon.withValues(alpha: 0.45 * pulse),
            AppColors.moon.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 3.4)),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.moon);
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()..color = const Color(0xFFFFF1C4),
    );
  }

  /// The golden-hour sun, low on the right: a wide glow and slow beams,
  /// and the disc itself where the sky is free of content.
  void _paintLowSun(Canvas canvas, Size size, double t, {required bool disc}) {
    final center = Offset(size.width * 0.8, size.height * 0.335);
    final radius = size.width * 0.12;
    final pulse = 0.92 + 0.08 * math.sin(t * _tau * 2);

    canvas.drawCircle(
      center,
      radius * 5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.moon.withValues(alpha: 0.5 * pulse),
            AppColors.skyRose.withValues(alpha: 0.18),
            AppColors.skyRose.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 5)),
    );
    if (!disc) return;

    // Long beams fanning up and out, swaying a little.
    final beam = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (var i = 0; i < 7; i++) {
      final a = math.pi + 0.25 + i * 0.34 + 0.04 * math.sin(t * _tau + i);
      final dir = Offset(math.cos(a), math.sin(a));
      final normal = Offset(-dir.dy, dir.dx);
      final start = center + dir * radius * 1.1;
      final end = center + dir * radius * 4.2;
      beam.color = AppColors.moon.withValues(
        alpha: (0.14 + 0.06 * math.sin(t * _tau * 3 + i)) * pulse,
      );
      canvas.drawPath(
        Path()
          ..moveTo(start.dx + normal.dx * 2, start.dy + normal.dy * 2)
          ..lineTo(end.dx + normal.dx * 14, end.dy + normal.dy * 14)
          ..lineTo(end.dx - normal.dx * 14, end.dy - normal.dy * 14)
          ..lineTo(start.dx - normal.dx * 2, start.dy - normal.dy * 2)
          ..close(),
        beam,
      );
    }

    canvas.drawCircle(center, radius, Paint()..color = AppColors.moon);
    canvas.drawCircle(
      center,
      radius * 0.8,
      Paint()..color = const Color(0xFFFFD98E),
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.18, -radius * 0.2),
      radius * 0.45,
      Paint()..color = const Color(0xFFFFEBC0),
    );
  }

  /// A few birds far off, flapping their way home.
  void _paintBirds(Canvas canvas, Size size, double t) {
    // (start x, height, size, cycles per loop).
    const birds = [
      (0.10, 0.17, 1.0, 1),
      (0.16, 0.20, 0.8, 1),
      (0.62, 0.12, 0.7, 2),
    ];
    final paint = Paint()
      ..color = AppColors.ridgeNear.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (x0, y, scale, cycles) in birds) {
      final span = size.width * 1.2;
      final x = ((x0 + t * cycles) % 1.0) * span - size.width * 0.1;
      final cy = size.height * y + math.sin(t * _tau * 4 + x0 * 9) * 3;
      final w = 9 * scale;
      final flap = math.sin(t * _tau * 24 + x0 * 20) * w * 0.45;
      canvas.drawPath(
        Path()
          ..moveTo(x - w, cy - flap)
          ..quadraticBezierTo(x - w * 0.45, cy - w * 0.35, x, cy)
          ..quadraticBezierTo(x + w * 0.45, cy - w * 0.35, x + w, cy - flap),
        paint,
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size, double t, {bool golden = false}) {
    // (x, y, scale, cycles per loop). Whole-number cycles keep the loop
    // seamless.
    const clouds = [
      (0.10, 0.07, 1.0, 1),
      (0.55, 0.15, 0.8, 1),
      (0.85, 0.05, 0.65, 2),
      (0.35, 0.24, 0.55, 2),
    ];
    // Golden hour: fewer, flatter clouds, lit peach from below.
    final paint = Paint()
      ..color = golden
          ? const Color(0xFFFFE3C4).withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final (x0, y, scale, cycles) in golden ? clouds.take(3) : clouds) {
      final w = size.width * (golden ? 0.4 : 0.34) * scale;
      final span = size.width + w * 2;
      final x = ((x0 + t * cycles) % 1.0) * span - w;
      final cy = size.height * y;
      final h = w * (golden ? 0.26 : 0.34);
      final puffs = [
        Rect.fromCenter(center: Offset(x, cy), width: w, height: h),
        Rect.fromCircle(
          center: Offset(x - w * 0.18, cy - h * 0.35),
          radius: h * 0.55,
        ),
        Rect.fromCircle(
          center: Offset(x + w * 0.12, cy - h * 0.5),
          radius: h * 0.7,
        ),
      ];
      for (final r in puffs) {
        canvas.drawOval(r, paint);
      }
    }
  }

  void _paintMoon(Canvas canvas, Size size, double t) {
    final center = Offset(size.width * 0.18, size.height * 0.11);
    final radius = size.width * 0.075;
    final pulse = 0.85 + 0.15 * math.sin(t * _tau * 2);

    canvas.drawCircle(
      center,
      radius * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.moon.withValues(alpha: 0.22 * pulse),
            AppColors.moon.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 3.2)),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.moon);
    // Two soft "seas" so it reads as a moon, not a dot.
    final sea = Paint()..color = const Color(0xFFEBD9C0);
    canvas.drawCircle(
      center + Offset(-radius * 0.3, -radius * 0.2),
      radius * 0.28,
      sea,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.32, radius * 0.3),
      radius * 0.18,
      sea,
    );
  }

  void _paintRidge(
    Canvas canvas,
    Size size,
    _Ridge ridge, {
    required Color top,
    required Color base,
  }) {
    final peak = size.height * (ridge.baseline - ridge.amplitude);
    canvas.drawPath(
      ridge.path(size),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base],
        ).createShader(Rect.fromLTRB(0, peak, size.width, size.height)),
    );
  }

  void _paintMist(
    Canvas canvas,
    Size size,
    double t, {
    required double y,
    required double speed,
    required double alpha,
  }) {
    final paint = Paint()
      ..color = AppColors.mist.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    const puffs = 4;
    final span = size.width * 1.6;
    for (var i = 0; i < puffs; i++) {
      final x = ((i / puffs + t * speed) % 1.0) * span - size.width * 0.3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, size.height * y + (i.isEven ? 6 : -6)),
          width: size.width * 0.7,
          height: size.height * 0.045,
        ),
        paint,
      );
    }
  }

  void _paintPines(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ridgeNear;
    final rng = math.Random(3);
    for (var x = -6.0; x < size.width + 12; x += 9 + rng.nextDouble() * 14) {
      final ground = _near.yAt(x / size.width, size) + 3;
      final h = 16 + rng.nextDouble() * 22;
      final w = h * 0.42;
      // Three overlapping triangles, each wider and lower, form a fir.
      for (var tier = 0; tier < 3; tier++) {
        final apex = ground - h + h * tier * 0.26;
        final base = apex + h * 0.48;
        final half = w * (0.55 + tier * 0.25);
        canvas.drawPath(
          Path()
            ..moveTo(x, apex)
            ..lineTo(x + half, base)
            ..lineTo(x - half, base)
            ..close(),
          paint,
        );
      }
    }
  }

  void _paintEmbers(Canvas canvas, Size size, double t) {
    for (final e in _embers) {
      final y = ((e.y - t * e.speed * 2) % 1.0) * size.height;
      final x = (e.x + math.sin(t * _tau * 3 + e.phase) * 0.02) * size.width;
      final twinkle = 0.45 + 0.55 * math.sin(t * _tau * 6 + e.phase).abs();
      canvas.drawCircle(
        Offset(x, y),
        e.radius * 1.9,
        Paint()
          ..color = AppColors.ember.withValues(
            alpha: (_light ? 0.22 : 0.35) * twinkle,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 2.2),
      );
      canvas.drawCircle(
        Offset(x, y),
        e.radius * 0.6,
        Paint()..color = AppColors.cream.withValues(alpha: 0.8 * twinkle),
      );
    }
  }

  void _paintFallingLeaves(Canvas canvas, Size size, double t) {
    for (final l in _leaves) {
      final progress = (t * 3 + l.offset) % 1.0;
      final y = -30 + progress * (size.height + 60);
      final x =
          (l.x + math.sin(progress * _tau * 2 + l.phase) * 0.06) * size.width;
      final length = l.size * 2;
      final w = length * 0.24;
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.45, -w, length, 0)
        ..quadraticBezierTo(length * 0.45, w, 0, 0)
        ..close();
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(progress * _tau * l.spin + l.phase)
        ..drawPath(
          leaf,
          Paint()
            ..color = (l.warm ? AppColors.rust : AppColors.ember).withValues(
              alpha: 0.7,
            ),
        )
        ..restore();
    }
  }

  void _paintGroundFade(Canvas canvas, Rect rect) {
    // Darkens the lower part so the call-to-action stays readable.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.night.withValues(alpha: 0.6),
            AppColors.night,
          ],
          // In light scenes the ground brightens sooner, so dark text
          // reads well.
          stops: _light ? const [0.46, 0.66, 0.9] : const [0.58, 0.8, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_DuskPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.showMoon != showMoon ||
      oldDelegate.scene != scene;
}
