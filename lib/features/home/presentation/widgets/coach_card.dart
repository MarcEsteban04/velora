import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/velora_mascot.dart';

/// Velora's message for right now, in the user's chosen coaching tone, with
/// one clear next step.
class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.toneLabel,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String toneLabel;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 18, 16),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const VeloraMascot(pose: MascotPose.wave, size: 104, halo: false),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VELORA · ${toneLabel.toUpperCase()}',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.ember,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onAction();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.leaf,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              actionLabel,
                              style: text.titleMedium?.copyWith(
                                fontSize: 14,
                                color: AppColors.onBrand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.onBrand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
