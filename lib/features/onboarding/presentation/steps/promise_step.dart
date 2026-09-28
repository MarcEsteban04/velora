import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/feature_tile.dart';
import '../widgets/mascot_says.dart';
import '../widgets/step_layout.dart';

class PromiseStep extends ConsumerWidget {
  const PromiseStep({super.key});

  static List<(IconData, Color, String, String)> get _promises => [
    (
      Icons.insights_rounded,
      AppColors.sky,
      'See where it goes',
      'Log spending in seconds and spot your patterns at a glance.',
    ),
    (
      Icons.pie_chart_rounded,
      AppColors.leafBright,
      'Budget without the stress',
      'Set limits per category and get a nudge before you overspend.',
    ),
    (
      Icons.flag_rounded,
      AppColors.ember,
      'Reach your goals',
      'Save for the things that matter, one small step at a time.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(onboardingControllerProvider).firstName;

    return StepLayout(
      children: [
        const SizedBox(height: 8),
        const MascotSays(
          pose: MascotPose.wallet,
          message: "Here's what we'll do together!",
        ),
        const SizedBox(height: 20),
        StepHeader(
          title: 'Money, made calm',
          subtitle:
              'Hi $name! Here is how Velora helps you stay on top of '
              'things, without the spreadsheets.',
        ),
        const SizedBox(height: 22),
        GlassCard(
          child: Column(
            children: [
              for (final (i, p) in _promises.indexed) ...[
                if (i > 0) const SizedBox(height: 20),
                FadeSlideIn(
                  delay: Duration(milliseconds: 250 + i * 120),
                  child: FeatureTile(
                    icon: p.$1,
                    color: p.$2,
                    title: p.$3,
                    body: p.$4,
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
