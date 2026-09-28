import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/streak.dart';
import '../streak_style.dart';

/// The streak count on Home. The flame (or leaf) is solid once today counts,
/// breathes gently while today is still open, and turns grey at zero. When
/// the count goes up it gives a little hop.
class StreakChip extends StatefulWidget {
  const StreakChip({super.key, required this.streak, required this.onTap});

  final Streak streak;
  final VoidCallback onTap;

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip> with TickerProviderStateMixin {
  late final _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncBreath();
  }

  @override
  void didUpdateWidget(StreakChip old) {
    super.didUpdateWidget(old);
    if (widget.streak.current > old.streak.current) {
      HapticFeedback.lightImpact();
      _hop.forward(from: 0);
    }
    _syncBreath();
  }

  void _syncBreath() {
    if (widget.streak.atRisk) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.streak;
    final live = s.current > 0 && s.today != TodayState.over;
    final tint = live ? s.settings.color : AppColors.textMuted;
    final secured =
        s.today == TodayState.secured ||
        (s.settings.goal == StreakGoal.underCap && s.current > 0);

    final hop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 35),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_hop);

    return Semantics(
      button: true,
      label:
          '${s.current} ${s.settings.unit(s.current)}. '
          '${s.atRisk ? 'Not logged today yet. ' : ''}Opens streak details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 44,
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tint.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: hop,
                child: FadeTransition(
                  opacity: Tween(begin: 0.45, end: 1.0).animate(_breath),
                  child: Icon(
                    secured || !live
                        ? s.settings.icon
                        : switch (s.settings.goal) {
                            StreakGoal.logging =>
                              Icons.local_fire_department_outlined,
                            StreakGoal.underCap => Icons.eco_outlined,
                          },
                    size: 22,
                    color: tint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Text(
                  '${s.current}',
                  key: ValueKey(s.current),
                  style: TextStyle(
                    fontFamily: AppTypography.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: live ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
