import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../home/presentation/home_screen.dart';
import '../application/onboarding_controller.dart';
import 'steps/account_step.dart';
import 'steps/celebration_step.dart';
import 'steps/coach_step.dart';
import 'steps/currency_step.dart';
import 'steps/features_step.dart';
import 'steps/name_step.dart';
import 'steps/promise_step.dart';
import 'steps/ready_step.dart';
import 'widgets/onboarding_progress.dart';

enum OnboardingStep {
  name,
  promise,
  currency,
  account,
  celebrate,
  features,
  coach,
  ready,
}

/// Eight short steps from "hello" to a first account. Answers live in the
/// in-memory draft until the last step, then everything is saved at once.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  static Route<void> route() => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, _, _) => const OnboardingFlow(),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pages = PageController();
  int _index = 0;
  bool _saving = false;

  OnboardingStep get _step => OnboardingStep.values[_index];
  bool get _isLast => _index == OnboardingStep.values.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _canContinue(OnboardingDraft draft) => switch (_step) {
    OnboardingStep.name => draft.firstName.isNotEmpty,
    OnboardingStep.account => draft.accountName.trim().isNotEmpty,
    _ => true,
  };

  String get _nextLabel => switch (_step) {
    OnboardingStep.account => 'Create account',
    OnboardingStep.ready => 'Start tracking',
    _ => 'Continue',
  };

  Future<void> _goTo(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pages.jumpToPage(index);
    } else {
      await _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (!_canContinue(ref.read(onboardingControllerProvider))) return;
    if (_isLast) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
    } else {
      _goTo(_index - 1);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).complete();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't reach Velora. Check your connection and try again.",
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pushAndRemoveUntil(HomeScreen.route(), (_) => false);
  }

  Widget _buildStep(OnboardingStep step) => switch (step) {
    OnboardingStep.name => NameStep(onSubmit: _next),
    OnboardingStep.promise => const PromiseStep(),
    OnboardingStep.currency => const CurrencyStep(),
    OnboardingStep.account => const AccountStep(),
    OnboardingStep.celebrate => const CelebrationStep(),
    OnboardingStep.features => const FeaturesStep(),
    OnboardingStep.coach => const CoachStep(),
    OnboardingStep.ready => const ReadyStep(),
  };

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final text = Theme.of(context).textTheme;

    return PopScope(
      // The system back gesture steps back through onboarding, not out of it.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.night,
        ),
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: DuskBackdrop()),
              // A scrim keeps forms readable over the living scene.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.night.withValues(alpha: 0.35),
                        AppColors.night.withValues(alpha: 0.7),
                        AppColors.night.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OnboardingProgress(
                              count: OnboardingStep.values.length,
                              index: _index,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${_index + 1}/${OnboardingStep.values.length}',
                            style: text.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final step in OnboardingStep.values)
                            _buildStep(step),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 60,
                            child: TextButton(
                              onPressed: _saving ? null : _back,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                textStyle: text.titleMedium,
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PressableButton(
                              label: _saving ? 'Saving…' : _nextLabel,
                              onPressed: _canContinue(draft) && !_saving
                                  ? _next
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
