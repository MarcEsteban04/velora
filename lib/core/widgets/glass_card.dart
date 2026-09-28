import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A translucent panel over the scene.
///
/// It used to blur what was behind it (a BackdropFilter). That re-blurs on
/// every frame anything behind it moves, including while scrolling, and
/// with a dozen cards on screen it heated phones. A firmer tint keeps text
/// just as readable for a fraction of the work.
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: shape,
        border: Border.all(color: AppColors.hairline(0.08)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
