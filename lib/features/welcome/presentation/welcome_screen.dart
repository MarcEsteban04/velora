import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pressable_button.dart';
import 'widgets/forest_backdrop.dart';
import 'widgets/mascot_hero.dart';

/// The first screen users see.
///
/// Velora is offline-first and needs no account, so there's one clear
/// call-to-action instead of a sign-in wall. If cloud sign-in is added later,
/// its buttons go in the actions column above "Get started".
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
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.forestNight,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ForestBackdrop()),
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
                              _Reveal(
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
                              _Reveal(
                                animation: _intro,
                                interval: const Interval(
                                  0.25,
                                  0.7,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: const _Wordmark(),
                              ),
                              const SizedBox(height: 14),
                              _Reveal(
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
                              _Reveal(
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
                              const SizedBox(height: 18),
                              _Reveal(
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
                Shadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  offset: const Offset(0, 5),
                  blurRadius: 16,
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
            child: const Text('Velora', style: AppTypography.wordmark),
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
        const Icon(Icons.lock_rounded, size: 15, color: AppColors.leafBright),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'No account needed · Your data stays on this device',
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Fades a child in and slides it up (optionally scaling it too) over one
/// [interval] of a shared intro animation, for a staggered entrance.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.interval,
    required this.child,
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final Curve interval;
  final double scaleFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: interval);

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final v = curved.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 24),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
