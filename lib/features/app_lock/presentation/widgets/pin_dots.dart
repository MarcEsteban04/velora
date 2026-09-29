import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/security/pin_policy.dart';
import '../../../../core/theme/app_colors.dart';

enum PinDotsState { idle, error, success }

/// Four dots that fill as digits are typed. Changing [errorTick] triggers a
/// shake, and [state] tints the dots red (error) or green (success).
class PinDots extends StatefulWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.state = PinDotsState.idle,
    this.errorTick = 0,
  });

  final int filled;
  final PinDotsState state;
  final int errorTick;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTick != oldWidget.errorTick &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      PinDotsState.error => AppColors.rust,
      PinDotsState.success => AppColors.leafBright,
      PinDotsState.idle => AppColors.accentBright,
    };

    return Semantics(
      label: '${widget.filled} of ${PinPolicy.length} digits entered',
      liveRegion: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          // A decaying sine wave: a quick "no" headshake.
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PinPolicy.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: AnimatedScale(
                  scale: i < widget.filled ? 1.15 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < widget.filled ? color : Colors.transparent,
                      border: Border.all(
                        color: i < widget.filled
                            ? color
                            : AppColors.textMuted.withValues(alpha: 0.7),
                        width: 2,
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
