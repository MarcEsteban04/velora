import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/velora_mascot.dart';

/// Velora's insight for right now, in the user's coaching tone. Just the
/// insight: actions live in the + button. The phone's own note shows first
/// and gives way to the AI's when it arrives.
class CoachCard extends StatelessWidget {
  const CoachCard({super.key, required this.message, this.aiMessage});

  final String message;

  /// The AI's note, when there is one.
  final String? aiMessage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.skyPlum.withValues(alpha: 0.55),
            AppColors.surface.withValues(alpha: 0.75),
          ],
        ),
        border: Border.all(color: AppColors.ember.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const VeloraMascot(pose: MascotPose.wave, size: 96, halo: false),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: 'Velora says: ${aiMessage ?? message}',
              excludeSemantics: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Column(
                  key: ValueKey(aiMessage ?? message),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      aiMessage ?? message,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (aiMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: AppColors.ember,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
