import 'package:flutter/material.dart';

import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/speech_bubble.dart';
import '../../../../core/widgets/velora_mascot.dart';

/// Velora on the left with a speech bubble at the top right. The bubble pops
/// whenever [message] changes.
class MascotSays extends StatelessWidget {
  const MascotSays({
    super.key,
    required this.pose,
    required this.message,
    this.size = 150,
  });

  final MascotPose pose;
  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Velora says: $message',
      liveRegion: true,
      excludeSemantics: true,
      child: SizedBox(
        height: size * 1.02,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: FadeSlideIn(
                scaleFrom: 0.8,
                curve: Curves.easeOutBack,
                child: VeloraMascot(pose: pose, size: size),
              ),
            ),
            Positioned(
              top: 0,
              left: size * 0.8,
              right: 0,
              child: Align(
                alignment: Alignment.topLeft,
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      alignment: Alignment.bottomLeft,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: SpeechBubble(
                      key: ValueKey(message),
                      speaker: 'Velora',
                      message: message,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
