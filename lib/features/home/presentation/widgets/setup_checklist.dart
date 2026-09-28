import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class SetupTask {
  const SetupTask({
    required this.title,
    required this.subtitle,
    required this.done,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;
}

/// "Get set up": a short list of quick wins with a progress ring. It turns
/// the empty-app moment into momentum, and hides itself once everything is
/// done.
class SetupChecklist extends StatelessWidget {
  const SetupChecklist({super.key, required this.tasks});

  final List<SetupTask> tasks;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).length;
    if (done == tasks.length) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              _ProgressRing(
                progress: done / tasks.length,
                label: '$done/${tasks.length}',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get set up', style: text.titleMedium),
                    Text(
                      'A few quick wins to get the most out of Velora.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in tasks) _TaskRow(task: task),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final SetupTask task;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: task.done ? null : task.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.done ? AppColors.leafBright : Colors.transparent,
                  border: Border.all(
                    color: task.done
                        ? AppColors.leafBright
                        : AppColors.textMuted,
                    width: 1.6,
                  ),
                ),
                child: task.done
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.night,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: text.titleMedium?.copyWith(
                        fontSize: 14,
                        color: task.done
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                    Text(task.subtitle, style: text.labelMedium),
                  ],
                ),
              ),
              if (!task.done && task.onTap != null)
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = AppColors.hairline(0.1);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [AppColors.leafBright, AppColors.ember, AppColors.leafBright],
      ).createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
