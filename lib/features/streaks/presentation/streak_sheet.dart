import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../profile/data/profile_repository.dart';
import '../application/streak_providers.dart';
import '../domain/streak.dart';
import '../domain/flame.dart';
import 'streak_celebration.dart';
import 'streak_goal_sheet.dart';
import 'streak_style.dart';
import 'widgets/flame_icon.dart';

/// The streak up close: the count, where today stands, the week, badges
/// and the goal. It stays live, so logging something updates it in place.
abstract final class StreakSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _StreakSheet(),
  );

  /// Opens the goal picker and saves the result. Shared with Settings.
  static Future<void> editGoal(BuildContext context, WidgetRef ref) async {
    final currency = Currencies.byCode(
      ref.read(profileProvider).value?.currencyCode ?? 'USD',
    );
    final current = ref.read(streakSettingsProvider);
    final picked = await StreakGoalSheet.show(
      context,
      current: current,
      currency: currency,
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    await ref.read(streakSettingsProvider.notifier).save(picked);
  }
}

class _StreakSheet extends ConsumerWidget {
  const _StreakSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final streak = ref.watch(streakProvider);
    final currency = Currencies.byCode(
      ref.watch(profileProvider).value?.currencyCode ?? 'USD',
    );

    if (streak == null) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final s = streak.settings;
    final live = streak.current > 0 && streak.today != TodayState.over;
    final tint = live ? streak.tint : AppColors.textMuted;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint.withValues(alpha: 0.16),
                  ),
                  child: Center(
                    child: StreakGlyph(
                      goal: s.goal,
                      tier: streak.tier,
                      size: 36,
                      dim: !live,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.current}',
                        style: TextStyle(
                          fontFamily: AppTypography.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 40,
                          height: 1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        s.unit(streak.current),
                        style: text.titleMedium?.copyWith(color: tint),
                      ),
                    ],
                  ),
                ),
                VeloraMascot(
                  pose: streak.current > 0
                      ? MascotPose.streak
                      : MascotPose.wave,
                  size: 88,
                  halo: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withValues(alpha: 0.2)),
              ),
              child: Text(
                streak.message(currency),
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Label('Last 7 days'),
            const SizedBox(height: 10),
            _WeekStrip(streak: streak),
            const SizedBox(height: 22),
            _Label('Badges'),
            const SizedBox(height: 10),
            _Badges(streak: streak),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Best streak',
                    value:
                        '${streak.best} ${streak.best == 1 ? 'day' : 'days'}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    label: 'Goal',
                    value: s.label(currency),
                    onTap: () => StreakSheet.editGoal(context, ref),
                  ),
                ),
              ],
            ),
            if (s.restDays) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.bedtime_rounded, size: 15, color: AppColors.lilac),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'One missed day a week is forgiven as a rest day.',
                      style: text.labelMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 11, letterSpacing: 1.4),
  );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = streak.tint;

    String describe(DayMark m) => switch (m) {
      DayMark.done => 'done',
      DayMark.rest => 'rest day',
      DayMark.missed => 'missed',
      DayMark.pending => 'today, still open',
      DayMark.notStarted => 'before you started',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, (day, mark)) in streak.week.indexed)
          Semantics(
            label: '${DateFormat('EEEE').format(day)}: ${describe(mark)}',
            excludeSemantics: true,
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: Duration(milliseconds: 300 + i * 50),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: _DayDot(
                    mark: mark,
                    tint: tint,
                    icon: streak.settings.icon,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i == streak.week.length - 1
                      ? 'Today'
                      : DateFormat('E').format(day),
                  style: text.labelMedium?.copyWith(
                    fontSize: 11,
                    color: i == streak.week.length - 1
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.mark, required this.tint, required this.icon});

  final DayMark mark;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final (fill, border, child) = switch (mark) {
      DayMark.done => (
        tint.withValues(alpha: 0.9),
        tint,
        Icon(icon, size: 19, color: AppColors.onBrand),
      ),
      DayMark.rest => (
        AppColors.lilac.withValues(alpha: 0.16),
        AppColors.lilac.withValues(alpha: 0.5),
        Icon(Icons.bedtime_rounded, size: 17, color: AppColors.lilac),
      ),
      DayMark.missed => (
        Colors.transparent,
        AppColors.hairline(0.14),
        Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
      ),
      DayMark.pending => (
        tint.withValues(alpha: 0.08),
        tint.withValues(alpha: 0.7),
        Icon(icon, size: 17, color: tint.withValues(alpha: 0.6)),
      ),
      DayMark.notStarted => (
        Colors.transparent,
        AppColors.hairline(0.06),
        const SizedBox.shrink(),
      ),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.6),
      ),
      child: Center(child: child),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = streak.tint;
    final flame = streak.settings.goal == StreakGoal.logging;
    final next = streak.nextMilestone;
    final from = streak.lastMilestone;
    final progress = next == null
        ? 1.0
        : (streak.current - from) / (next - from);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${next - streak.current} more to the $next-day badge',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${streak.current} / $next',
                style: text.labelMedium?.copyWith(color: tint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: AppColors.hairline(0.08)),
                  ),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        heightFactor: 1,
                        child: ColoredBox(color: tint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in streakMilestones)
              _BadgeChip(
                days: m,
                earned: streak.best >= m,
                goal: streak.settings.goal,
                tint: flame ? FlameTier.of(m).tint : tint,
                // An earned badge replays its moment.
                onTap: streak.best >= m
                    ? () => StreakCelebration.show(
                        context,
                        days: m,
                        goal: streak.settings.goal,
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.days,
    required this.earned,
    required this.goal,
    required this.tint,
    this.onTap,
  });

  final int days;
  final bool earned;
  final StreakGoal goal;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$days-day badge, ${earned ? 'earned' : 'not earned yet'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: earned ? tint.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: earned
                  ? tint.withValues(alpha: 0.35)
                  : AppColors.hairline(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (earned)
                StreakGlyph(goal: goal, tier: FlameTier.of(days), size: 15)
              else
                Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '$days',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: earned ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.hairline(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.labelMedium?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: AppColors.accentBright,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
