import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
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
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../application/budget_providers.dart';
import '../domain/budget.dart';
import 'budget_editor_sheet.dart';
import 'budget_style.dart';
import 'widgets/budget_card.dart';

/// Every budget, how they're doing together, and the categories that don't
/// have one yet (with a suggestion from last month).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const BudgetsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final views = ref.watch(budgetStatusesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final lastMonth = ref.watch(lastMonthSpendProvider) ?? const {};

    final budgeted = {
      for (final v in views ?? const <BudgetView>[]) v.category.id,
    };
    final open =
        categories
            .where(
              (c) =>
                  c.kind == TransactionKind.expense && !budgeted.contains(c.id),
            )
            .toList()
          ..sort(
            (a, b) => (lastMonth[b.id] ?? 0).compareTo(lastMonth[a.id] ?? 0),
          );

    void edit(Category c, [Budget? existing]) => BudgetEditorSheet.show(
      context,
      category: c,
      currency: currency,
      existing: existing,
      lastMonthMinor: lastMonth[c.id],
    );

    Future<void> pickCategory() async {
      final c = await showModalBottomSheet<Category>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _CategoryPicker(
          categories: open,
          lastMonth: lastMonth,
          currency: currency,
        ),
      );
      if (c != null && context.mounted) edit(c);
    }

    final List<Widget> body;
    if (budgetsAsync.hasError && !budgetsAsync.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(budgetsAsync.error!, action: 'load budgets'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(budgetsProvider),
              ),
            ],
          ),
        ),
      ];
    } else if (views == null) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.leafBright),
          ),
        ),
      ];
    } else if (views.isEmpty) {
      body = [
        FadeSlideIn(child: _EmptyState(onStart: pickCategory)),
        if (open.isNotEmpty) ...[
          _Section('Start with one'),
          _OpenCategories(
            categories: open.take(6).toList(),
            lastMonth: lastMonth,
            currency: currency,
            onTap: edit,
          ),
        ],
      ];
    } else {
      body = [
        FadeSlideIn(
          child: _Summary(
            totals: BudgetTotals.of(views),
            currency: currency,
            count: views.length,
          ),
        ),
        _Section('Your budgets'),
        for (final (i, v) in views.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              delay: Duration(milliseconds: 60 * (i + 1)),
              child: BudgetCard(
                view: v,
                currency: currency,
                onTap: () => edit(v.category, v.status.budget),
              ),
            ),
          ),
        if (open.isNotEmpty) ...[
          _Section('Not budgeted yet'),
          _OpenCategories(
            categories: open,
            lastMonth: lastMonth,
            currency: currency,
            onTap: edit,
          ),
        ],
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Budgets',
      actions: [
        if (open.isNotEmpty)
          RoundIconButton(
            icon: Icons.add_rounded,
            semanticLabel: 'Add a budget',
            active: true,
            onTap: pickCategory,
          ),
      ],
      onRefresh: () async {
        ref
          ..invalidate(budgetsProvider)
          ..invalidate(budgetTransactionsProvider);
        await ref.read(budgetsProvider.future);
      },
      children: body,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(fontSize: 11, letterSpacing: 1.4),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.totals,
    required this.currency,
    required this.count,
  });

  final BudgetTotals totals;
  final Currency currency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = totals.overCount > 0
        ? AppColors.rust
        : totals.used >= 0.85
        ? AppColors.ember
        : AppColors.leafBright;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: totals.used,
                color: color,
                size: 92,
                stroke: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(totals.used * 100).round()}%',
                      style: text.headlineSmall?.copyWith(fontSize: 20),
                    ),
                    Text(
                      'USED',
                      style: text.labelMedium?.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEFT TO SPEND',
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Money.format(totals.remainingMinor, currency),
                        style: text.displaySmall?.copyWith(fontSize: 26),
                      ),
                    ),
                    Text(
                      'of ${Money.format(totals.limitMinor, currency)} across '
                      '$count ${count == 1 ? 'budget' : 'budgets'}',
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.leaf.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.today_rounded,
                  size: 18,
                  color: AppColors.leafBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Safe to spend today', style: text.labelMedium),
                ),
                Text(
                  Money.format(totals.dailyAllowanceMinor, currency),
                  style: text.titleMedium?.copyWith(
                    color: AppColors.leafBright,
                  ),
                ),
              ],
            ),
          ),
          if (totals.overCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_rounded, size: 16, color: AppColors.rust),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    totals.overCount == 1
                        ? 'One budget is over. It’s at the top.'
                        : '${totals.overCount} budgets are over. They’re at the top.',
                    style: text.labelMedium?.copyWith(color: AppColors.rust),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        children: [
          const VeloraMascot(pose: MascotPose.coin, size: 120, halo: false),
          const SizedBox(height: 8),
          Text('Give your money a job', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Set a limit for one category. Velora tracks the pace and tells '
            'you what’s safe to spend each day.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          PressableButton(label: 'Set a budget', onPressed: onStart),
        ],
      ),
    );
  }
}

class _OpenCategories extends StatelessWidget {
  const _OpenCategories({
    required this.categories,
    required this.lastMonth,
    required this.currency,
    required this.onTap,
  });

  final List<Category> categories;
  final Map<String, int> lastMonth;
  final Currency currency;
  final void Function(Category) onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, c) in categories.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 66, color: AppColors.hairline(0.06)),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onTap(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CategoryBadge(
                        icon: c.iconData,
                        color: c.colorValue,
                        size: 38,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: text.titleMedium?.copyWith(fontSize: 14),
                            ),
                            Text(switch (lastMonth[c.id]) {
                              final m? when m > 0 =>
                                '${Money.format(m, currency)} last month',
                              _ => 'No spending last month',
                            }, style: text.labelMedium),
                          ],
                        ),
                      ),
                      Text(
                        'Set',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.leafBright,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.lastMonth,
    required this.currency,
  });

  final List<Category> categories;
  final Map<String, int> lastMonth;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Budget a category', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text('Sorted by last month’s spending.', style: text.bodyMedium),
              const SizedBox(height: 12),
              _OpenCategories(
                categories: categories,
                lastMonth: lastMonth,
                currency: currency,
                onTap: (c) => Navigator.pop(context, c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
