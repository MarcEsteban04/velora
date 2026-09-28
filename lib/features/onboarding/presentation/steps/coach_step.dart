import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/coach_tone_style.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/selectable_tile.dart';
import '../widgets/step_layout.dart';

class CoachStep extends ConsumerWidget {
  const CoachStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final tone = draft.coachTone;
    final text = Theme.of(context).textTheme;

    return StepLayout(
      children: [
        const SizedBox(height: 16),
        const StepHeader(
          title: 'How should Velora cheer you on?',
          subtitle:
              'Velora reacts to your spending. Pick the voice that '
              'motivates you most.',
        ),
        const SizedBox(height: 18),
        for (final (i, option) in CoachTone.values.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              delay: Duration(milliseconds: 150 + i * 90),
              child: SelectableTile(
                selected: option == tone,
                semanticLabel: '${option.label}: ${option.description}',
                onTap: () => notifier.setCoachTone(option),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: option.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(option.icon, color: option.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.label, style: text.titleMedium),
                          Text(option.description, style: text.bodyMedium),
                        ],
                      ),
                    ),
                    SelectionDot(selected: option == tone),
                  ],
                ),
              ),
            ),
          ),
        const FieldLabel('Preview'),
        _Reaction(
          pose: MascotPose.coin,
          tag: 'On track',
          tagColor: AppColors.leafBright,
          message: tone.onTrackExample(draft.firstName),
        ),
        const SizedBox(height: 10),
        _Reaction(
          pose: MascotPose.wallet,
          tag: 'Heads-up',
          tagColor: AppColors.ember,
          message: tone.headsUpExample,
        ),
      ],
    );
  }
}

class _Reaction extends StatelessWidget {
  const _Reaction({
    required this.pose,
    required this.tag,
    required this.tagColor,
    required this.message,
  });

  final MascotPose pose;
  final String tag;
  final Color tagColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 420),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: tagColor.withValues(alpha: 0.5)),
            ),
            // Zoom in on the face so it reads at avatar size.
            child: ClipOval(
              child: Transform.scale(
                scale: 1.6,
                alignment: const Alignment(0, -0.75),
                child: Image.asset(pose.asset, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag, style: text.labelMedium?.copyWith(color: tagColor)),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      message,
                      key: ValueKey(message),
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
