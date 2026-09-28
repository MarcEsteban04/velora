import 'package:flutter/material.dart';

/// Fades a child in and slides it up (optionally scaling it too) over one
/// [interval] of a shared [animation]. Several of these on one controller give
/// a staggered entrance.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.animation,
    required this.child,
    this.interval = const Interval(0, 1, curve: Curves.easeOutCubic),
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final Curve interval;
  final double scaleFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: interval);

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final v = curved.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 24),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// A self-running [Reveal]: plays once when first built, after [delay].
/// Handy for a stagger without wiring up a controller.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.scaleFrom = 1,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double scaleFrom;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Reveal(
      animation: _controller,
      interval: widget.curve,
      scaleFrom: widget.scaleFrom,
      child: widget.child,
    );
  }
}
