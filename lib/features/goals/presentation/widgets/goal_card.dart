import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_visuals.dart';
import '../../domain/goal.dart';
import '../goal_style.dart';

/// A goal at a glance: icon, name, saved of target, a bar and its outlook.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.progress, required this.onTap});

  final GoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final g = p.goal;
    final tint = g.colorValue;

    return Semantics(
      button: true,
      label:
          '${g.name}: ${Money.format(p.savedMinor, g.currency)} of '
          '${Money.format(g.targetMinor, g.currency)}. ${p.outlook}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      p.isDone ? Icons.emoji_events_rounded : g.iconData,
                      color: tint,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        Text(
                          '${Money.format(p.savedMinor, g.currency)} of '
                          '${Money.short(g.targetMinor, g.currency)}',
                          style: text.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(p.fraction * 100).floor()}%',
                    style: text.titleMedium?.copyWith(color: tint),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: p.fraction, color: tint),
              const SizedBox(height: 6),
              Text(
                p.outlook,
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  color: p.health == GoalHealth.open
                      ? AppColors.textMuted
                      : p.healthColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
