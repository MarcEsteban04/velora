import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../app_lock/presentation/widgets/pin_creator.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/step_layout.dart';

class PinStep extends ConsumerWidget {
  const PinStep({super.key, required this.onCreated});

  /// Called once the PIN is confirmed, so the flow can move on by itself.
  final VoidCallback onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return StepLayout(
      children: [
        PinCreator(
          header: (context, confirming) => StepHeader(
            center: true,
            title: confirming ? 'Confirm your PIN' : 'Protect your space',
            subtitle: confirming
                ? 'Enter it once more so we know it’s right.'
                : "Create a 4-digit PIN. You'll use it to open Velora.",
          ),
          onCreated: (pin) {
            ref.read(onboardingControllerProvider.notifier).setPin(pin);
            Future<void>.delayed(const Duration(milliseconds: 550), onCreated);
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_rounded, size: 14, color: AppColors.accentBright),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Stays on this phone and is never sent to our servers',
                textAlign: TextAlign.center,
                style: text.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
