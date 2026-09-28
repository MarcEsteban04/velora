import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../../accounts/presentation/account_type_style.dart';
import '../../../profile/presentation/coach_tone_style.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/step_layout.dart';

class ReadyStep extends ConsumerWidget {
  const ReadyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);

    final rows = [
      (
        Icons.currency_exchange_rounded,
        AppColors.leafBright,
        'Currency',
        '${draft.currency.code} · ${draft.currency.name}',
      ),
      (
        draft.accountType.icon,
        AppColors.sky,
        'First account',
        '${draft.accountName.trim()} · '
            '${Money.format(draft.openingBalanceMinor, draft.currency)}',
      ),
      (
        draft.coachTone.icon,
        draft.coachTone.color,
        'Coaching style',
        draft.coachTone.label,
      ),
    ];

    return StepLayout(
      children: [
        const SizedBox(height: 8),
        const Center(
          child: FadeSlideIn(
            scaleFrom: 0.7,
            curve: Curves.easeOutBack,
            child: VeloraMascot(pose: MascotPose.thumbsUp, size: 200),
          ),
        ),
        const SizedBox(height: 12),
        StepHeader(
          center: true,
          title: "You're all set, ${draft.firstName}!",
          subtitle:
              "Here's your starting point. It's saved securely and only "
              'you can see it.',
        ),
        const SizedBox(height: 22),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, color: AppColors.hairline(0.06)),
                FadeSlideIn(
                  delay: Duration(milliseconds: 250 + i * 110),
                  child: _SummaryRow(
                    icon: r.$1,
                    color: r.$2,
                    label: r.$3,
                    value: r.$4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label, style: text.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
