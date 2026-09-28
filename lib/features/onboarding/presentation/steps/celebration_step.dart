import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../../accounts/presentation/widgets/account_card.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/mascot_says.dart';
import '../widgets/step_layout.dart';

class CelebrationStep extends ConsumerStatefulWidget {
  const CelebrationStep({super.key});

  @override
  ConsumerState<CelebrationStep> createState() => _CelebrationStepState();
}

class _CelebrationStepState extends ConsumerState<CelebrationStep> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final text = Theme.of(context).textTheme;

    return Stack(
      children: [
        StepLayout(
          children: [
            const SizedBox(height: 28),
            MascotSays(
              pose: MascotPose.coin,
              size: 170,
              message: 'Congrats on your first account, ${draft.firstName}!',
            ),
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              scaleFrom: 0.9,
              curve: Curves.easeOutBack,
              child: AccountCard(
                name: draft.accountName.trim(),
                type: draft.accountType,
                currency: draft.currency,
                balanceMinor: draft.openingBalanceMinor,
                countUp: true,
              ),
            ),
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: const Duration(milliseconds: 600),
              child: Text(
                'A small step toward calmer money.',
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
            ),
          ],
        ),
        const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}
