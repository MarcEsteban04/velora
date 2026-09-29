import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pressable_button.dart';
import '../application/streak_celebrations.dart';
import '../application/streak_providers.dart';
import '../domain/flame.dart';
import '../domain/streak.dart';
import 'streak_style.dart';
import 'widgets/flame_icon.dart';

/// A badge's big moment: confetti, the medal springing in with its rays,
/// the flame lighting up in its new colour, and what comes next.
abstract final class StreakCelebration {
  static Future<void> show(
    BuildContext context, {
    required int days,
    required StreakGoal goal,
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '$days-day badge',
      barrierColor: AppColors.night.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, _, _) => _Celebration(days: days, goal: goal),
      transitionBuilder: (context, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}

/// Watches the streak and celebrates each badge the first time it's
/// reached. Lives in the app shell, so it catches badges from any tab.
class StreakCelebrationListener extends ConsumerStatefulWidget {
  const StreakCelebrationListener({super.key});

  @override
  ConsumerState<StreakCelebrationListener> createState() =>
      _StreakCelebrationListenerState();
}

class _StreakCelebrationListenerState
    extends ConsumerState<StreakCelebrationListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<Streak?>(streakProvider, (_, next) async {
      if (next == null || !next.settings.enabled || _showing) return;
      final due = await ref.read(streakCelebrationsProvider).take(next);
      if (due == null || !mounted) return;
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await StreakCelebration.show(
          context,
          days: due,
          goal: next.settings.goal,
        );
        _showing = false;
      });
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.days, required this.goal});

  final int days;
  final StreakGoal goal;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (_intro.isDismissed) {
      _intro.forward();
      _turn.repeat();
      // A little double tap as the flame lights.
      Future<void>.delayed(
        const Duration(milliseconds: 420),
        HapticFeedback.mediumImpact,
      );
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _turn.dispose();
    super.dispose();
  }

  double _span(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_intro.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final flame = widget.goal == StreakGoal.logging;
    final tier = FlameTier.of(widget.days);
    final tint = flame ? tier.tint : AppColors.leafBright;
    final newColour = flame && tier.from == widget.days;
    final next = streakMilestones.where((m) => m > widget.days).firstOrNull;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: ConfettiBurst()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _turn]),
                  builder: (context, _) {
                    final medal = _span(0.0, 0.55, Curves.elasticOut);
                    final ignite = _span(0.18, 0.6, Curves.easeOutBack);
                    final rays = _span(0.12, 0.5);
                    final count = _span(0.1, 0.55);
                    Widget rise(double a, Widget child) {
                      final p = _span(a, a + 0.3);
                      return Opacity(
                        opacity: p,
                        child: Transform.translate(
                          offset: Offset(0, (1 - p) * 18),
                          child: child,
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: rays,
                                child: Transform.rotate(
                                  angle: _turn.value * math.pi * 2,
                                  child: CustomPaint(
                                    size: const Size(260, 260),
                                    painter: _Rays(tint, grow: rays),
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: medal,
                                child: _Medal(
                                  tint: tint,
                                  core: flame
                                      ? tier.core
                                      : AppColors.leafBright,
                                  child: Transform.scale(
                                    scale: 0.3 + 0.7 * ignite,
                                    child: StreakGlyph(
                                      goal: widget.goal,
                                      tier: tier,
                                      size: 92,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 30,
                                child: Transform.scale(
                                  scale: medal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tint,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${(widget.days * count).round()} DAYS',
                                      style: TextStyle(
                                        fontFamily: AppTypography.display,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 1.2,
                                        color: AppColors.onBrand,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        rise(
                          0.34,
                          Text(
                            '${widget.days}-day streak!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 34,
                              height: 1.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        rise(
                          0.42,
                          Text(
                            'You earned the ${widget.days}-day badge.',
                            textAlign: TextAlign.center,
                            style: text.bodyLarge,
                          ),
                        ),
                        if (newColour) ...[
                          const SizedBox(height: 16),
                          rise(0.5, _NewColour(tier: tier)),
                        ],
                        const SizedBox(height: 14),
                        rise(
                          0.58,
                          Text(
                            next == null
                                ? 'Every badge earned. Legendary.'
                                : 'Next badge at $next days',
                            textAlign: TextAlign.center,
                            style: text.labelMedium,
                          ),
                        ),
                        const SizedBox(height: 22),
                        rise(
                          0.64,
                          PressableButton(
                            label: 'Keep it going',
                            icon: Icons.local_fire_department_rounded,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The medal: a ring from the flame's core to its tip around a dark face.
class _Medal extends StatelessWidget {
  const _Medal({required this.tint, required this.core, required this.child});

  final Color tint;
  final Color core;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      height: 172,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [tint, core, tint]),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceRaised,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Flat rays round the medal, turning slowly.
class _Rays extends CustomPainter {
  _Rays(this.color, {required this.grow});

  final Color color;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2;
      final d = Offset(math.cos(a), math.sin(a));
      final long = i.isEven ? 1.0 : 0.7;
      canvas.drawLine(c + d * 100, c + d * (100 + 26 * long * grow), paint);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => old.color != color || old.grow != grow;
}

/// "Your flame burns blue now", with the old flame turning into the new.
class _NewColour extends StatelessWidget {
  const _NewColour({required this.tier});

  final FlameTier tier;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final before = tier.previous;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      decoration: BoxDecoration(
        color: tier.tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tier.tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (before != null) ...[
            StreakGlyph(goal: StreakGoal.logging, tier: before, size: 22),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
          StreakGlyph(goal: StreakGoal.logging, tier: tier, size: 26),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tier.phrase,
              style: text.titleMedium?.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
