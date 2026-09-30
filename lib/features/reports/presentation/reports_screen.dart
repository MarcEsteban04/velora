import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../../transactions/presentation/transaction_details_sheet.dart';
import '../application/report_providers.dart';
import '../domain/month_report.dart';
import 'widgets/report_charts.dart';

/// Where the money went, a month at a time: what came in, went out and was
/// kept (against last month), Velora's take, spending by category, the
/// month's pace against last month's, six months of in and out, and the
/// biggest expenses. Main currency only.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ReportsScreen());

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _month = monthKey(AppClock.now());

  bool get _isCurrent => _month == monthKey(AppClock.now());

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(monthKey(AppClock.now()))) return;
    HapticFeedback.selectionClick();
    setState(() => _month = next);
  }

  Future<void> _refresh() async {
    for (var i = 0; i < 6; i++) {
      ref.invalidate(
        monthTransactionsProvider(DateTime(_month.year, _month.month - i)),
      );
    }
    ref.invalidate(reportInsightProvider(_month));
    await ref.read(monthTransactionsProvider(_month).future);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final report = ref.watch(monthReportProvider(_month));
    final previous = ref.watch(
      monthReportProvider(DateTime(_month.year, _month.month - 1)),
    );
    final flows = ref.watch(monthFlowsProvider(_month));
    final take = ref.watch(reportInsightProvider(_month)).value;
    String money(int m) =>
        hidden ? '${currency.symbol}••••' : Money.format(m, currency);

    final switcher = Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(_month),
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: _isCurrent ? null : () => _shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );

    final List<Widget> body;
    if (report == null) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.leafBright),
          ),
        ),
      ];
    } else if (report.isEmpty) {
      body = [
        GlassCard(
          child: Column(
            children: [
              const VeloraMascot(
                pose: MascotPose.budget,
                size: 110,
                halo: false,
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing logged in ${DateFormat('MMMM').format(_month)}',
                style: text.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Log what you spend and earn, and this fills up with where '
                'it all went.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ];
    } else {
      // An unfinished month compares with last month by the same day.
      final spentBefore = previous == null || previous.isEmpty
          ? null
          : _isCurrent
          ? previous.spentByDay(report.daysCounted)
          : previous.spentMinor;
      final incomeBefore = previous == null || previous.isEmpty
          ? null
          : previous.incomeMinor;
      final vs = previous == null
          ? null
          : 'vs ${DateFormat('MMM').format(previous.month)}'
                '${_isCurrent ? ', same day' : ''}';

      body = [
        if (take != null)
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.leafBright,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(take, style: text.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
        FadeSlideIn(
          // Equal heights, however the notes wrap.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Spent',
                    value: money(report.spentMinor),
                    change: spentBefore == null
                        ? null
                        : changeOf(report.spentMinor, spentBefore),
                    vs: vs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Earned',
                    value: money(report.incomeMinor),
                    change: incomeBefore == null
                        ? null
                        : changeOf(report.incomeMinor, incomeBefore),
                    vs: vs == null
                        ? null
                        : 'vs ${DateFormat('MMM').format(previous!.month)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Kept',
                    value: money(report.keptMinor),
                    note: switch (report.savingsRate) {
                      final r? when r > 0 => '${(r * 100).round()}% of income',
                      final r? when r < 0 => 'More out than in',
                      _ => null,
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${money(report.dailyAverageMinor)} a day on average · '
          '${report.expenseCount} expense${report.expenseCount == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: text.labelMedium,
        ),
        const SizedBox(height: 16),
        if (report.byCategory.isNotEmpty)
          _Section(
            title: 'Where it went',
            child: _CategoryList(
              report: report,
              money: money,
              onOpen: (c) =>
                  _CategorySheet.show(context, month: _month, category: c),
            ),
          ),
        if (report.cumulative.isNotEmpty && report.spentMinor > 0)
          _Section(
            title: _isCurrent ? 'Spending pace' : 'How it built up',
            child: PaceChart(
              report: report,
              previous: previous == null || previous.isEmpty ? null : previous,
              currency: currency,
              hidden: hidden,
            ),
          ),
        if (flows.length > 1)
          _Section(
            title: 'Last 6 months',
            child: FlowColumns(
              flows: flows,
              currency: currency,
              hidden: hidden,
              selected: _month,
            ),
          ),
        if (report.biggest.isNotEmpty)
          _Section(
            title: 'Biggest expenses',
            child: _Biggest(report: report, money: money),
          ),
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Reports',
      onRefresh: _refresh,
      actions: [
        RoundIconButton(
          icon: Icons.today_rounded,
          semanticLabel: 'This month',
          active: _isCurrent,
          onTap: () => setState(() => _month = monthKey(AppClock.now())),
        ),
      ],
      children: [switcher, const SizedBox(height: 6), ...body],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FadeSlideIn(
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title.toUpperCase(),
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A number, and how it moved against last month. The arrow and words
/// carry the direction; nothing relies on colour.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.change,
    this.vs,
    this.note,
  });

  final String label;
  final String value;
  final double? change;
  final String? vs;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = change;
    final flat = c != null && c.abs() < 0.005;
    final delta = c == null
        ? note
        : flat
        ? 'Same ${vs ?? ''}'.trim()
        : '${(c.abs() * 100).round()}% ${vs ?? ''}'.trim();
    final small = text.labelMedium?.copyWith(fontSize: 10);
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMedium?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleMedium?.copyWith(fontSize: 16)),
          ),
          if (delta != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The arrow says which way; the words say by how much.
                if (c != null && !flat)
                  Padding(
                    padding: const EdgeInsets.only(right: 2, top: 1),
                    child: Icon(
                      c > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: AppColors.textMuted,
                      semanticLabel: c > 0 ? 'up' : 'down',
                    ),
                  ),
                Expanded(child: Text(delta, maxLines: 2, style: small)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Categories as a ranked list with a bar each: one hue for magnitude,
/// the icon and name for identity. Doubles as the table view.
class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.report,
    required this.money,
    required this.onOpen,
  });

  final MonthReport report;
  final String Function(int) money;
  final ValueChanged<Category?> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = report.byCategory.first.share;
    return Column(
      children: [
        for (final c in report.byCategory)
          Semantics(
            button: true,
            label:
                '${c.category?.name ?? report.restLabel}, ${money(c.amountMinor)}, '
                '${(c.share * 100).round()} percent',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(c.category),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (c.category?.colorValue ?? AppColors.textMuted)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        c.category?.iconData ?? Icons.more_horiz_rounded,
                        size: 17,
                        color: c.category?.colorValue ?? AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.category?.name ?? report.restLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                money(c.amountMinor),
                                style: text.titleMedium?.copyWith(fontSize: 13),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(c.share * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: text.labelMedium?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          LayoutBuilder(
                            builder: (context, box) => Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: top == 0
                                    ? 0
                                    : (c.share / top * box.maxWidth).clamp(
                                        3.0,
                                        box.maxWidth,
                                      ),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: ReportColors.spending,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Biggest extends StatelessWidget {
  const _Biggest({required this.report, required this.money});

  final MonthReport report;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final t in report.biggest)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => TransactionDetailsSheet.show(context, t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (t.note?.trim().isNotEmpty ?? false)
                              ? t.note!.trim()
                              : 'Expense',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 13),
                        ),
                        Text(
                          DateFormat('EEE, MMM d').format(t.occurredAt),
                          style: text.labelMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(t.amountMinor),
                    style: text.titleMedium?.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One category's spending in a month, biggest first.
abstract final class _CategorySheet {
  static Future<void> show(
    BuildContext context, {
    required DateTime month,
    required Category? category,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategoryTransactions(month: month, category: category),
  );
}

class _CategoryTransactions extends ConsumerWidget {
  const _CategoryTransactions({required this.month, required this.category});

  final DateTime month;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final report = ref.watch(monthReportProvider(month));
    final all =
        ref.watch(monthTransactionsProvider(monthKey(month))).value ??
        const <Transaction>[];
    final top = {
      for (final c in report?.byCategory ?? const <CategorySpend>[])
        if (c.category != null) c.category!.id,
    };
    final list = all.where((t) {
      if (t.kind != TransactionKind.expense) return false;
      final id = category?.id;
      // Other: no category, or one folded into the tail.
      return id == null ? !top.contains(t.categoryId) : t.categoryId == id;
    }).toList()..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    String money(int m) =>
        hidden ? '${currency.symbol}••••' : Money.format(m, currency);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              category?.name ?? report?.restLabel ?? 'Other',
              style: text.headlineSmall,
            ),
            Text(
              '${DateFormat('MMMM y').format(month)} · ${list.length} '
              'expense${list.length == 1 ? '' : 's'} · '
              '${money(list.fold(0, (s, t) => s + t.amountMinor))}',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final t in list)
              InkWell(
                onTap: () => TransactionDetailsSheet.show(context, t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (t.note?.trim().isNotEmpty ?? false)
                                  ? t.note!.trim()
                                  : category?.name ?? 'Expense',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(fontSize: 14),
                            ),
                            Text(
                              DateFormat('EEE, MMM d · h:mm a')
                                  .format(t.occurredAt),
                              style: text.labelMedium?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(t.amountMinor),
                        style: text.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
