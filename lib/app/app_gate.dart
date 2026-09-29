import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/friendly_error.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/dusk_backdrop.dart';
import '../core/widgets/pressable_button.dart';
import '../core/widgets/reveal.dart';
import '../core/widgets/velora_mascot.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/updates/presentation/update_prompter.dart';
import '../features/welcome/presentation/welcome_screen.dart';

/// Chooses the first screen: Welcome for new users, Home for returning ones.
/// While the profile loads it shows a splash, and when Supabase can't be
/// reached it shows a friendly offline screen with a retry button.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    // Check loading first: a retry after an error reports both "error" and
    // "loading", and the splash should win so the tap feels acknowledged.
    final Widget screen;
    if (profile.isLoading && !profile.hasValue) {
      screen = const _SplashView(key: ValueKey('splash'));
    } else if (profile.hasError) {
      screen = _OfflineView(
        key: const ValueKey('offline'),
        error: profile.error!,
        onRetry: () => ref.invalidate(profileProvider),
      );
    } else if (profile.value == null) {
      screen = WelcomeScreen(
        key: const ValueKey('welcome'),
        onGetStarted: () => Navigator.of(context).push(OnboardingFlow.route()),
      );
    } else {
      screen = const UpdatePrompter(key: ValueKey('shell'), child: AppShell());
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: screen,
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.night,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: DuskBackdrop()),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return _StatusScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VeloraMascot(pose: MascotPose.wave, size: 180),
          SizedBox(height: 28),
          SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.accentBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _StatusScaffold(
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VeloraMascot(pose: MascotPose.wallet, size: 170),
            const SizedBox(height: 20),
            Text(
              isNetworkError(error)
                  ? "Can't reach Velora right now"
                  : 'Velora hit a snag',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              '${friendlyError(error, action: 'load your space')} '
              'Your data is safe.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 28),
            PressableButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
