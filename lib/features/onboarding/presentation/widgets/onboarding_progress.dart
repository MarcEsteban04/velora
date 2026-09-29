import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A segmented progress bar. Finished steps are green, and the current step
/// is a wider, glowing pill.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: i == index ? 3 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: i <= index
                      ? (i == index ? AppColors.accentBright : AppColors.accent)
                      : AppColors.hairline(0.14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
