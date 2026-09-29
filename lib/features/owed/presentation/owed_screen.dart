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
import '../application/owed_providers.dart';
import '../domain/owed.dart';
import 'owed_detail_sheet.dart';
import 'owed_editor_sheet.dart';
import 'owed_style.dart';

/// Who still owes the user: the total out there, how much has come back,
/// who's overdue, and each person on the way to paid back.
class OwedScreen extends ConsumerStatefulWidget {
  const OwedScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const OwedScreen());

  @override
  ConsumerState<OwedScreen> createState() => _OwedScreenState();
}

class _OwedScreenState extends ConsumerState<OwedScreen> {
  bool _showSettled = false;

  void _reload() => ref
    ..invalidate(owedProvider)
    ..invalidate(owedEntriesProvider);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final main = ref.watch(mainCurrencyProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final owedAsync = ref.watch(owedProvider);
    final list = ref.watch(owedProgressProvider);
    final now = AppClock.now();

    void add() => OwedEditorSheet.show(context, currency: main);

    final List<Widget> body;
    if (owedAsync.hasError && !owedAsync.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(owedAsync.error!, action: 'load who owes you'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: _reload,
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
                  pose: MascotPose.coin,
                  size: 120,
                  halo: false,
                ),
                const SizedBox(height: 8),
                Text('Who owes you?', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Lunch you covered, a loan to a friend, your share of the '
                  'bill. Add it and Velora keeps count until it’s back.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                PressableButton(label: 'Add someone', onPressed: add),
              ],
            ),
          ),
        ),
      ];
    } else {
      final owing = list.where((p) => !p.isSettled).toList();
      final settled = list.where((p) => p.isSettled).toList();
      final totals = OwedTotals.of(
        list.where((p) => p.owed.currencyCode == main.code),
      );
      final overdue = owing.where((p) => p.isOverdue(now)).length;
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
                  owing.isEmpty ? 'ALL PAID BACK' : 'OWED TO YOU',
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
                  '${money(totals.backMinor, main)} back of '
                  '${money(totals.lentMinor, main)} lent · '
                  '${owing.length} still owing',
                  style: text.labelMedium,
                ),
                if (overdue > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppColors.rust,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          overdue == 1
                              ? '${owing.firstWhere((p) => p.isOverdue(now)).owed.name} is past the pay-back date'
                              : '$overdue people are past their pay-back date',
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
              child: _OwedCard(
                progress: p,
                money: money,
                outlook: owedOutlook(p, now),
                overdue: p.isOverdue(now),
                onTap: () => OwedDetailSheet.show(context, p.owed.id),
              ),
            ),
          ),
        if (settled.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showSettled = !_showSettled),
              icon: Icon(
                _showSettled
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showSettled
                    ? 'Hide paid back'
                    : 'Paid back (${settled.length})',
              ),
            ),
          ),
          if (_showSettled)
            for (final p in settled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OwedCard(
                  progress: p,
                  money: money,
                  outlook: owedOutlook(p, now),
                  overdue: false,
                  onTap: () => OwedDetailSheet.show(context, p.owed.id),
                ),
              ),
        ],
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Owed to you',
      onRefresh: () async {
        _reload();
        await ref.read(owedProvider.future);
      },
      actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Add someone who owes you',
          onTap: add,
        ),
      ],
      children: body,
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({
    required this.progress,
    required this.money,
    required this.outlook,
    required this.overdue,
    required this.onTap,
  });

  final OwedProgress progress;
  final String Function(int minor, Currency c) money;
  final String outlook;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final c = Currencies.byCode(p.owed.currencyCode);
    return Semantics(
      button: true,
      label: '${p.owed.name}, ${money(p.remainingMinor, c)} owed',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              OwedAvatar(owed: p.owed, settled: p.isSettled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.owed.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          p.isSettled
                              ? money(p.lentMinor, c)
                              : money(p.remainingMinor, c),
                          style: text.titleMedium?.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ProgressBar(
                      value: p.fraction,
                      color: p.owed.color,
                      height: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outlook.isEmpty ? 'Owes you' : outlook,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        color: overdue ? AppColors.rust : null,
                      ),
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
