import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../application/planned_providers.dart';
import '../domain/planned_payment.dart';
import 'pay_planned_sheet.dart';
import 'planned_detail_sheet.dart';
import 'planned_editor_sheet.dart';
import 'planned_style.dart';

/// Bills and income on a schedule: what's due over the next 30 days, then
/// each one by how soon it is, with Pay right on the row.
class PlannedScreen extends ConsumerStatefulWidget {
  const PlannedScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const PlannedScreen());

  @override
  ConsumerState<PlannedScreen> createState() => _PlannedScreenState();
}

class _PlannedScreenState extends ConsumerState<PlannedScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final main = ref.watch(mainCurrencyProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final async = ref.watch(plannedProvider);
    final active = ref.watch(activePlannedProvider);
    final totals = ref.watch(upcomingTotalsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
    final now = AppClock.now();

    Currency currencyFor(PlannedPayment p) =>
        Currencies.byCode(currencyOf[p.accountId] ?? main.code);
    String money(int m, Currency c) =>
        hidden ? '${c.symbol}••••' : Money.format(m, c);

    void add({
      (String, String, PlannedRepeat)? template,
      bool income = false,
    }) => PlannedEditorSheet.show(context, template: template, income: income);

    final List<Widget> body;
    if (async.hasError && !async.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(
                  async.error!,
                  action: 'load your planned payments',
                ),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(plannedProvider),
              ),
            ],
          ),
        ),
      ];
    } else if (active == null || totals == null) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          ),
        ),
      ];
    } else if (async.value!.isEmpty) {
      body = [
        FadeSlideIn(
          child: GlassCard(
            child: Column(
              children: [
                const VeloraMascot(
                  pose: MascotPose.streak,
                  size: 120,
                  halo: false,
                ),
                const SizedBox(height: 8),
                Text('Never miss a bill', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Rent, electricity, subscriptions, even your salary. '
                  'Velora reminds you before each one, and one tap logs it.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in plannedTemplates)
                      ActionChip(
                        label: Text(t.$1),
                        onPressed: () => add(template: t),
                      ),
                    ActionChip(
                      label: const Text('Salary'),
                      onPressed: () => add(income: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PressableButton(label: 'Plan a payment', onPressed: add),
              ],
            ),
          ),
        ),
      ];
    } else {
      final done = async.value!.where((p) => p.isDone).toList()
        ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
      final groups = <DueStatus, List<PlannedPayment>>{};
      for (final p in active) {
        (groups[dueStatus(p, now)] ??= []).add(p);
      }
      var i = 0;
      Widget row(PlannedPayment p) => FadeSlideIn(
        delay: Duration(milliseconds: 60 + (i++).clamp(0, 8) * 40),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlannedRow(
            planned: p,
            category: categories.where((c) => c.id == p.categoryId).firstOrNull,
            amount: money(p.amountMinor, currencyFor(p)),
            now: now,
          ),
        ),
      );

      body = [
        FadeSlideIn(
          child: _SummaryCard(totals: totals, main: main, money: money),
        ),
        const SizedBox(height: 16),
        for (final status in DueStatus.values)
          if (groups[status] case final list?) ...[
            _GroupHeader(
              status.label,
              color: status == DueStatus.overdue ? AppColors.rust : null,
            ),
            for (final p in list) row(p),
            const SizedBox(height: 6),
          ],
        if (done.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showDone = !_showDone),
              icon: Icon(
                _showDone
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(_showDone ? 'Hide done' : 'Done (${done.length})'),
            ),
          ),
          if (_showDone)
            for (final p in done)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlannedRow(
                  planned: p,
                  category: categories
                      .where((c) => c.id == p.categoryId)
                      .firstOrNull,
                  amount: money(p.amountMinor, currencyFor(p)),
                  now: now,
                ),
              ),
        ],
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Planned payments',
      onRefresh: () async {
        ref.invalidate(plannedProvider);
        await ref.read(plannedProvider.future);
      },
      actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Plan a payment',
          onTap: add,
        ),
      ],
      children: body,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totals,
    required this.main,
    required this.money,
  });

  final UpcomingTotals totals;
  final Currency main;
  final String Function(int minor, Currency c) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget stat(String label, int minor, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: text.labelMedium?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(minor, main),
              style: text.titleMedium?.copyWith(fontSize: 18),
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT 30 DAYS',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              stat('Going out', totals.outMinor, AppColors.ember),
              if (totals.inMinor > 0) ...[
                const SizedBox(width: 12),
                stat('Coming in', totals.inMinor, AppColors.leafBright),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totals.count == 0
                ? 'Nothing due in the next 30 days.'
                : totals.count == 1
                ? '1 payment planned'
                : '${totals.count} payments planned',
            style: text.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(fontSize: 11, letterSpacing: 1.4, color: color),
    ),
  );
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({
    required this.planned,
    required this.category,
    required this.amount,
    required this.now,
  });

  final PlannedPayment planned;
  final Category? category;
  final String amount;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = planned;
    final status = dueStatus(p, now);
    final due = plannedDueLabel(p, now);
    final urgent = status == DueStatus.overdue || status == DueStatus.today;
    final info = Row(
      children: [
        PlannedBadge(planned: p, category: category),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  due,
                  if (p.autoLog && !p.isDone) 'logs itself',
                  if (p.repeat == PlannedRepeat.once) 'once',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  color: p.isDone ? null : dueColor(status),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          p.isIncome ? '+$amount' : amount,
          style: text.titleMedium?.copyWith(
            fontSize: 14,
            color: p.isIncome ? AppColors.leafBright : null,
          ),
        ),
      ],
    );
    return GlassCard(
      radius: 22,
      padding: EdgeInsets.fromLTRB(14, 12, p.isDone ? 16 : 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${p.name}, $amount, $due',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => PlannedDetailSheet.show(context, p.id),
                child: info,
              ),
            ),
          ),
          if (!p.isDone) ...[
            const SizedBox(width: 2),
            IconButton(
              tooltip: p.isIncome ? 'Log ${p.name}' : 'Pay ${p.name}',
              visualDensity: VisualDensity.compact,
              onPressed: () => PayPlannedSheet.show(context, p),
              icon: Icon(
                Icons.check_circle_outline_rounded,
                color: urgent
                    ? AppColors.accentBright
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
