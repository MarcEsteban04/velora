import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/welcome/presentation/welcome_screen.dart';

class VeloraApp extends ConsumerWidget {
  const VeloraApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: returning users start on Home, new users on Welcome. Later
    // navigation is handled by the screens themselves.
    final onboarded = ref.read(profileProvider) != null;

    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorKey: _navigatorKey,
      home: onboarded
          ? const HomeScreen()
          : WelcomeScreen(
              onGetStarted: () =>
                  _navigatorKey.currentState?.push(OnboardingFlow.route()),
            ),
    );
  }
}
