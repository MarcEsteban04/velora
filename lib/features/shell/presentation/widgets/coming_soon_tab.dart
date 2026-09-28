import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import 'floating_nav_bar.dart';

/// A friendly placeholder for tabs that are still being built. It previews
/// what's coming, so the tab doesn't feel like a dead end.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pose,
    required this.previews,
  });

  final String title;
  final String subtitle;
  final MascotPose pose;
  final List<(IconData, String)> previews;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 24,
        24,
        FloatingNavBar.reservedHeight(context),
      ),
      children: [
        FadeSlideIn(child: Text(title, style: text.displaySmall)),
        const SizedBox(height: 6),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: Text(subtitle, style: text.bodyLarge),
        ),
        const SizedBox(height: 28),
        Center(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            scaleFrom: 0.85,
            child: VeloraMascot(pose: pose, size: 170),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ember.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.ember,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final (icon, label) in previews)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: AppColors.leafBright),
                        const SizedBox(width: 12),
                        Expanded(child: Text(label, style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
