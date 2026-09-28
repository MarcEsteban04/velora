import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A frosted panel that blurs the animated scene behind it, so content stays
/// readable while the world keeps moving.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.62),
            borderRadius: shape,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
