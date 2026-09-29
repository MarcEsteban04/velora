import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/progress_visuals.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../application/debt_providers.dart';
import '../domain/debt.dart';
import 'debt_detail_sheet.dart';
import 'debt_editor_sheet.dart';
import 'debt_style.dart';

/// What the user owes: the total still to pay and how much is already
/// paid off, what's due next, and each debt on its way to zero.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const DebtsScreen());

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showPaidOff = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final main = ref.watch(mainCurrencyProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final debtsAsync = ref.watch(debtsProvider);
    final list = ref.watch(debtProgressProvider);
    final now = AppClock.now();

    void add([(String, DebtKind)? template]) =>
        DebtEditorSheet.show(context, currency: main, template: template);

    final List<Widget> body;
    if (debtsAsync.hasError && !debtsAsync.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(debtsAsync.error!, action: 'load your debts'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref
                  ..invalidate(debtsProvider)
                  ..invalidate(debtEntriesProvider)
                  ..invalidate(debtBillsProvider),
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
                  pose: MascotPose.wallet,
                  size: 120,
                  halo: false,
                ),
                const SizedBox(height: 8),
                Text('What do you owe?', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'A credit card, a pay-later plan, a loan or money from a '
                  'friend. Add it and Velora keeps count, all the way to zero.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in debtTemplates)
                      ActionChip(
                        avatar: Icon(t.$2.icon, size: 18, color: t.$2.color),
                        label: Text(t.$1),
                        onPressed: () => add(t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PressableButton(label: 'Add a debt', onPressed: add),
              ],
            ),
          ),
        ),
      ];
    } else {
      final owing = list.where((p) => !p.isPaidOff).toList();
      final paidOff = list.where((p) => p.isPaidOff).toList();
      final inMain = list.where((p) => p.debt.currencyCode == main.code);
      final totals = DebtTotals.of(inMain);
      final nextDue = owing.where((p) => p.nextDue != null).firstOrNull;
      String money(int m, Currency c) =>
          hidden ? '${c.symbol}••••' : Money.format(m, c);

      body = [
        FadeSlideIn(
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owing.isEmpty ? 'ALL PAID OFF' : 'YOU OWE',
                  style: text.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(totals.owedMinor, main),
                    style: text.displaySmall?.copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(height: 10),
                ProgressBar(
                  value: totals.fraction,
                  color: AppColors.leafBright,
                  height: 8,
                ),
                const SizedBox(height: 6),
                Text(
                  '${money(totals.paidMinor, main)} paid off of '
                  '${money(totals.totalMinor, main)} · '
                  '${owing.length} to go',
                  style: text.labelMedium,
                ),
                if (nextDue != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: AppColors.ember,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${dueLabel(nextDue.nextDue!, now)}: ${nextDue.debt.name}'
                          '${nextDue.debt.monthlyMinor == null ? '' : ' · ${money(nextDue.suggestedPaymentMinor, Currencies.byCode(nextDue.debt.currencyCode))}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, p) in owing.indexed)
          FadeSlideIn(
            delay: Duration(milliseconds: 60 + i * 40),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DebtCard(
                progress: p,
                money: money,
                outlook: debtOutlook(p, now),
                onTap: () => DebtDetailSheet.show(context, p.debt.id),
              ),
            ),
          ),
        if (paidOff.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showPaidOff = !_showPaidOff),
              icon: Icon(
                _showPaidOff
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showPaidOff ? 'Hide paid off' : 'Paid off (${paidOff.length})',
              ),
            ),
          ),
          if (_showPaidOff)
            for (final p in paidOff)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DebtCard(
                  progress: p,
                  money: money,
                  outlook: 'Paid off',
                  onTap: () => DebtDetailSheet.show(context, p.debt.id),
                ),
              ),
        ],
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Debts',
      onRefresh: () async {
        ref
          ..invalidate(debtsProvider)
          ..invalidate(debtEntriesProvider)
          ..invalidate(debtBillsProvider);
        await ref.read(debtsProvider.future);
      },
      actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Add a debt',
          onTap: add,
        ),
      ],
      children: body,
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.progress,
    required this.money,
    required this.outlook,
    required this.onTap,
  });

  final DebtProgress progress;
  final String Function(int minor, Currency c) money;
  final String outlook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final c = Currencies.byCode(p.debt.currencyCode);
    final color = p.debt.color;
    return Semantics(
      button: true,
      label: '${p.debt.name}, ${money(p.remainingMinor, c)} left',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              DebtBadge(debt: p.debt, paidOff: p.isPaidOff),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.debt.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          p.isPaidOff
                              ? money(p.totalMinor, c)
                              : money(p.remainingMinor, c),
                          style: text.titleMedium?.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressBar(value: p.fraction, color: color, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      outlook.isEmpty ? p.debt.kind.label : outlook,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(fontSize: 11),
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
