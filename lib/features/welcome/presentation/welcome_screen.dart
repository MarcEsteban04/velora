import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../auth/presentation/sign_in_sheet.dart';
import 'widgets/mascot_hero.dart';

/// The first screen users see.
///
/// Velora signs users in anonymously behind the scenes, so there's one clear
/// call-to-action instead of a sign-in wall. A quiet "I already have a
/// space" opens a backed-up space on a new phone.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// How long Velora celebrates before we move on.
  static const _celebration = Duration(milliseconds: 900);

  bool _celebrating = false;

  Future<void> _getStarted() async {
    setState(() => _celebrating = true);
    await Future<void>.delayed(_celebration);
    if (!mounted) return;
    widget.onGetStarted();
    setState(() => _celebrating = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (_intro.isDismissed) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mascotSize = math.min(
                    constraints.maxHeight * 0.34,
                    300.0,
                  );

                  // Centre a column at most 440 wide through padding, not Center,
                  // so the height constraint stays tight and the Spacers can
                  // pin the actions to the bottom.
                  final gutter = math.max(
                    24.0,
                    (constraints.maxWidth - 440) / 2,
                  );

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 20),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0,
                                  0.55,
                                  curve: Curves.easeOutBack,
                                ),
                                scaleFrom: 0.7,
                                child: MascotHero(
                                  size: mascotSize,
                                  celebrating: _celebrating,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.25,
                                  0.7,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: const _Wordmark(),
                              ),
                              const SizedBox(height: 14),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.35,
                                  0.8,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: Text(
                                  'Your cozy companion for tracking '
                                  'spending, budgets and goals, all in '
                                  'one calm place.',
                                  textAlign: TextAlign.center,
                                  style: text.bodyLarge,
                                ),
                              ),
                              const Spacer(flex: 2),
                              const SizedBox(height: 32),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.5,
                                  0.95,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: PressableButton(
                                  label: 'Get started',
                                  icon: Icons.eco_rounded,
                                  // Disabled while celebrating to block double taps.
                                  onPressed: _celebrating ? null : _getStarted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.55,
                                  1,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: TextButton(
                                  onPressed: _celebrating
                                      ? null
                                      : () => SignInSheet.show(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                  ),
                                  child: const Text('I already have a space'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.6,
                                  1,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: const _PrivacyNote(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Velora',
      excludeSemantics: true,
      // The shadow sits on its own layer beneath the text, so the gradient
      // mask only tints the letters and never the shadow.
      child: Stack(
        children: [
          Text(
            'Velora',
            style: AppTypography.wordmark.copyWith(
              color: Colors.transparent,
              shadows: [
                // By day a tighter, darker edge keeps the cream letters
                // crisp against the bright hills.
                Shadow(
                  color:
                      (AppColors.isDay ? const Color(0xFF1C3A26) : Colors.black)
                          .withValues(alpha: AppColors.isDay ? 0.55 : 0.45),
                  offset: const Offset(0, 5),
                  blurRadius: AppColors.isDay ? 12 : 16,
                ),
                if (AppColors.isDay)
                  Shadow(
                    color: const Color(0xFF1C3A26).withValues(alpha: 0.45),
                    offset: const Offset(0, 1.5),
                    blurRadius: 2,
                  ),
              ],
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AppColors.cream, Color(0xFFF6D9B8)],
            ).createShader(bounds),
            child: Text('Velora', style: AppTypography.wordmark),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: AppColors.textSecondary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded, size: 15, color: AppColors.leafBright),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'No sign-up needed · Your data stays private',
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}
