import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

enum MascotPose {
  wave(AppAssets.mascotWave),
  coin(AppAssets.mascotCoin),
  wallet(AppAssets.mascotWallet),
  thumbsUp(AppAssets.mascotThumbsUp);

  const MascotPose(this.asset);
  final String asset;
}

/// Velora, floating gently over a warm halo. Changing [pose] cross-fades to
/// the new artwork with a small pop.
class VeloraMascot extends StatefulWidget {
  const VeloraMascot({
    super.key,
    required this.pose,
    required this.size,
    this.halo = true,
  });

  final MascotPose pose;
  final double size;
  final bool halo;

  @override
  State<VeloraMascot> createState() => _VeloraMascotState();
}

class _VeloraMascotState extends State<VeloraMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final pose in MascotPose.values) {
      precacheImage(AssetImage(pose.asset), context);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.halo)
              Container(
                width: size * 0.95,
                height: size * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.ember.withValues(alpha: 0.26),
                      AppColors.leafBright.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _float,
              builder: (context, child) {
                final wave = math.sin(_float.value * math.pi * 2);
                return Transform.translate(
                  offset: Offset(0, wave * size * -0.025),
                  child: Transform.rotate(angle: wave * 0.02, child: child),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Image.asset(
                  widget.pose.asset,
                  key: ValueKey(widget.pose),
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
