import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/reveal.dart';
import '../widgets/feature_tile.dart';
import '../widgets/step_layout.dart';

class FeaturesStep extends StatelessWidget {
  const FeaturesStep({super.key});

  static List<(IconData, Color, String, String)> get _features => [
    (
      Icons.add_circle_rounded,
      AppColors.leafBright,
      'Quick add',
      'Tap +, enter an amount, pick a category. Done.',
    ),
    (
      Icons.document_scanner_rounded,
      AppColors.sky,
      'Scan receipts',
      'Snap a photo and Velora fills in the details.',
    ),
    (
      Icons.chat_bubble_rounded,
      AppColors.lilac,
      'Just tell Velora',
      'Type "coffee 150" and it\'s logged. Ask about your money anytime.',
    ),
    (
      Icons.notifications_active_rounded,
      AppColors.ember,
      'Smart nudges',
      'A heads-up before a budget runs out, not after.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StepLayout(
      children: [
        const SizedBox(height: 16),
        const StepHeader(
          title: 'Logging takes seconds',
          subtitle: 'However you like to track, Velora keeps up.',
        ),
        const SizedBox(height: 22),
        GlassCard(
          child: Column(
            children: [
              for (final (i, f) in _features.indexed) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.hairline(0.06)),
                  ),
                FadeSlideIn(
                  delay: Duration(milliseconds: 180 + i * 110),
                  child: FeatureTile(
                    icon: f.$1,
                    color: f.$2,
                    title: f.$3,
                    body: f.$4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
