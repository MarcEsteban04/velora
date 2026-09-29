import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/velora_mascot.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/speech_bubble.dart';

/// Velora the red panda, floating in place with a halo, a ground shadow and
/// a speech bubble. Tapping it makes it hop and say something new.
///
/// Set [celebrating] to switch it to the coin-hugging pose, for example right
/// after the user commits to something.
class MascotHero extends StatefulWidget {
  const MascotHero({
    super.key,
    required this.size,
    this.showBubble = true,
    this.celebrating = false,
  });

  final double size;
  final bool showBubble;
  final bool celebrating;

  static const celebrationLine = "Yay! Let's grow together!";

  static const lines = [
    "Hi, I'm Velora!",
    "Let's make money feel calm.",
    'Small steps, big savings.',
    'Psst… no sign-up needed!',
  ];

  @override
  State<MascotHero> createState() => _MascotHeroState();
}

class _MascotHeroState extends State<MascotHero> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  int _line = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the second pose now so the swap doesn't flash.
    precacheImage(MascotPose.coin.image(context, widget.size), context);
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void didUpdateWidget(MascotHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrating && !oldWidget.celebrating) _hopNow();
  }

  @override
  void dispose() {
    _float.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _hopNow() {
    if (!MediaQuery.disableAnimationsOf(context)) _hop.forward(from: 0);
  }

  void _onTap() {
    if (widget.celebrating) return;
    HapticFeedback.selectionClick();
    setState(() => _line = (_line + 1) % MascotHero.lines.length);
    _hopNow();
  }

  String get _message =>
      widget.celebrating ? MascotHero.celebrationLine : MascotHero.lines[_line];

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Semantics(
      button: true,
      label: 'Velora the red panda says: $_message',
      hint: 'Tap to hear something else',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _onTap,
        child: SizedBox(
          width: size * 1.25,
          height: size * 1.1,
          child: AnimatedBuilder(
            animation: Listenable.merge([_float, _hop]),
            builder: (context, _) {
              final wave = math.sin(_float.value * math.pi * 2);
              // One quick hop: up, then down with a little bounce.
              final hop = math.sin(
                Curves.easeOut.transform(_hop.value) * math.pi,
              );
              final lift = wave * size * 0.025 + hop * size * 0.12;
              final squash = 1 + math.sin(_hop.value * math.pi * 2) * 0.04;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Soft halo behind the mascot.
                  Container(
                    width: size * 0.95,
                    height: size * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.ember.withValues(alpha: 0.28),
                          AppColors.accentBright.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                  // Ground shadow, which shrinks as the mascot rises.
                  Positioned(
                    bottom: size * 0.04,
                    child: Transform.scale(
                      scale: 1 - (lift / size) * 1.6,
                      child: Container(
                        width: size * 0.62,
                        height: size * 0.11,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(size * 0.31, size * 0.055),
                          ),
                          gradient: RadialGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -lift),
                    child: Transform.rotate(
                      angle: wave * 0.025,
                      child: Transform.scale(
                        scaleX: squash,
                        scaleY: 2 - squash,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: Tween(
                                  begin: 0.85,
                                  end: 1.0,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Image(
                            image:
                                (widget.celebrating
                                        ? MascotPose.coin
                                        : MascotPose.wave)
                                    .image(context, size),
                            key: ValueKey(widget.celebrating),
                            width: size,
                            height: size,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.showBubble)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(0, -lift * 0.4),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: size * 0.62),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutBack,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  alignment: Alignment.bottomLeft,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: SpeechBubble(
                              key: ValueKey(_message),
                              speaker: 'Velora',
                              message: _message,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
