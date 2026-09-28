import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/progress_visuals.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../profile/application/main_currency.dart';
import '../application/goal_providers.dart';
import 'goal_detail_sheet.dart';
import 'goal_editor_sheet.dart';
import 'goal_style.dart';
import 'widgets/goal_card.dart';

/// Savings goals: each with its progress and outlook, plus the total set
/// aside.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const GoalsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final list = ref.watch(goalProgressProvider);

    void create([({String name, String icon, String color})? template]) =>
        GoalEditorSheet.show(context, currency: currency, template: template);

    final List<Widget> body;
    if (goalsAsync.hasError && !goalsAsync.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(goalsAsync.error!, action: 'load goals'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref
                  ..invalidate(goalsProvider)
                  ..invalidate(goalEntriesProvider),
              ),
            ],
          ),
        ),
      ];
    } else if (list == null) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.leafBright),
          ),
        ),
      ];
    } else if (list.isEmpty) {
      body = [
        FadeSlideIn(
          child: GlassCard(
            child: Column(
              children: [
                const VeloraMascot(
                  pose: MascotPose.thumbsUp,
                  size: 120,
                  halo: false,
                ),
                const SizedBox(height: 8),
                Text('What are you saving for?', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Name it, set a target and maybe a date. Velora tells you '
                  'how much to set aside each month.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in GoalStyle.templates)
                      ActionChip(
                        avatar: Icon(
                          GoalStyle.iconOf(t.icon),
                          size: 18,
                          color: GoalStyle.colorOf(t.color),
                        ),
                        label: Text(t.name),
                        onPressed: () => create(t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PressableButton(label: 'Create a goal', onPressed: create),
              ],
            ),
          ),
        ),
      ];
    } else {
      final active = list.where((p) => !p.isDone).toList();
      final saved = list
          .where((p) => p.goal.currencyCode == currency.code)
          .fold(0, (s, p) => s + p.savedMinor);
      final target = list
          .where((p) => p.goal.currencyCode == currency.code)
          .fold(0, (s, p) => s + p.goal.targetMinor);
      body = [
        FadeSlideIn(
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVED FOR GOALS',
                  style: text.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Money.format(saved, currency),
                  style: text.displaySmall?.copyWith(fontSize: 26),
                ),
                Text(
                  'of ${Money.format(target, currency)} · '
                  '${active.length} active, ${list.length - active.length} reached',
                  style: text.labelMedium,
                ),
                const SizedBox(height: 12),
                ProgressBar(
                  value: target == 0 ? 0 : saved / target,
                  color: AppColors.leafBright,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, p) in list.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              delay: Duration(milliseconds: 60 * (i + 1)),
              child: GoalCard(
                progress: p,
                onTap: () => GoalDetailSheet.show(context, p.goal.id),
              ),
            ),
          ),
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Goals',
      actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'New goal',
          active: true,
          onTap: create,
        ),
      ],
      onRefresh: () async {
        ref
          ..invalidate(goalsProvider)
          ..invalidate(goalEntriesProvider);
        await ref.read(goalsProvider.future);
      },
      children: body,
    );
  }
}
