import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../application/app_lock_controller.dart';
import '../data/pin_repository.dart';
import 'widgets/lock_scaffold.dart';
import 'widgets/pin_creator.dart';

/// Shown once to users who onboarded before PINs existed, and after a failed
/// PIN save, so every onboarded user ends up protected.
class PinSetupScreen extends ConsumerWidget {
  const PinSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return LockScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VeloraMascot(pose: MascotPose.thumbsUp, size: 140),
          const SizedBox(height: 12),
          PinCreator(
            header: (context, confirming) => Column(
              children: [
                Text(
                  confirming ? 'Confirm your PIN' : 'Protect your space',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  confirming
                      ? 'Enter it once more so we know it’s right.'
                      : 'Create a 4-digit PIN to open Velora.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
              ],
            ),
            onCreated: (pin) async {
              try {
                await ref.read(pinRepositoryProvider).setPin(pin);
                ref.read(appLockProvider.notifier).pinCreated();
              } on Object catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      friendlyError(error, action: 'save your PIN'),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
