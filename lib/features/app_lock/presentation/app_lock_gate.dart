import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../application/app_lock_controller.dart';
import '../data/pin_repository.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';

/// Sits above the whole navigator (via `MaterialApp.builder`), so the lock
/// covers every route, including sheets and dialogs. It only applies to users
/// who have finished onboarding.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child, required this.onReset});

  final Widget child;

  /// Returns the navigator to its root after a reset, so the app gate can
  /// show Welcome again.
  final VoidCallback onReset;

  Future<void> _startOver(WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(pinRepositoryProvider).clear();
    ref.read(appLockProvider.notifier).reset();
    ref.invalidate(profileProvider);
    onReset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(profileProvider).value != null;
    final lock = ref.watch(appLockProvider);

    Widget? cover;
    if (onboarded) {
      final state = lock.value;
      if (state == null) {
        // Still reading the keystore: cover with an opaque screen so
        // balances never flash before the lock appears.
        cover = const ColoredBox(
          key: ValueKey('pending'),
          color: AppColors.night,
        );
      } else if (!state.hasPin) {
        cover = const PinSetupScreen(key: ValueKey('setup'));
      } else if (state.locked) {
        cover = LockScreen(
          key: const ValueKey('lock'),
          onReset: () => _startOver(ref),
        );
      }
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: cover ?? const SizedBox.shrink(key: ValueKey('open')),
          ),
        ),
      ],
    );
  }
}
