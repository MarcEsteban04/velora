import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../budgets/application/budget_providers.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/budget_editor_sheet.dart';
import '../../budgets/presentation/budget_style.dart';
import '../../budgets/presentation/widgets/budget_card.dart';
import '../../budgets/presentation/widgets/budget_summary_card.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../../transactions/presentation/widgets/kind_switcher.dart';
import '../application/category_actions.dart';
import 'category_editor_sheet.dart';
import '../../../core/widgets/island_toast.dart';

/// Every category, with budgets for expenses: set limits, add custom
/// categories, edit, reorder by dragging, and hide or restore.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key, this.kind = TransactionKind.expense});

  final TransactionKind kind;

  static Route<void> route({TransactionKind kind = TransactionKind.expense}) =>
      MaterialPageRoute(builder: (_) => CategoriesScreen(kind: kind));

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  late TransactionKind _kind = widget.kind;

  /// A new order shown right away while it saves.
  List<String>? _pendingOrder;

  Currency get _currency => ref.read(mainCurrencyProvider);

  void _editBudget(Category c, Budget? existing) => BudgetEditorSheet.show(
    context,
    category: c,
    currency: _currency,
    existing: existing,
    lastMonthMinor: ref.read(lastMonthSpendProvider)?[c.id],
  );

  Future<void> _edit(Category c, Budget? budget) async {
    Widget? extra;
    if (c.kind == TransactionKind.expense) {
      extra = _BudgetLink(
        budget: budget,
        currency: _currency,
        onTap: () {
          Navigator.pop(context);
          _editBudget(c, budget);
        },
      );
    }
    await CategoryEditorSheet.show(
      context,
      kind: c.kind,
      existing: c,
      extra: extra,
    );
  }

  Future<void> _create() => CategoryEditorSheet.show(context, kind: _kind);

  Future<void> _reorder(List<Category> visible, int from, int to) async {
    final ids = [for (final c in visible) c.id];
    ids.insert(to, ids.removeAt(from));
    HapticFeedback.selectionClick();
    setState(() => _pendingOrder = ids);
    final toast = Toast.of(context);
    try {
      await CategoryActions.of(context).reorder(ids);
      await ref.read(categoriesProvider.future);
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'save the order'),
        tone: ToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
    }
  }

  Future<void> _restore(Category c) async {
    final toast = Toast.of(context);
    try {
      await CategoryActions.of(context).setHidden(c.id, false);
      HapticFeedback.selectionClick();
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'show the category'),
        tone: ToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final views = ref.watch(budgetStatusesProvider);
    final lastMonth = ref.watch(lastMonthSpendProvider) ?? const {};
    final budgetOf = {
      for (final v in views ?? const <BudgetView>[])
        v.category.id: v.status.budget,
    };

    final all = categoriesAsync.value ?? const <Category>[];
    var visible = all.where((c) => c.kind == _kind && !c.hidden).toList();
    if (_pendingOrder case final order?) {
      final pos = {for (final (i, id) in order.indexed) id: i};
      visible.sort((a, b) => (pos[a.id] ?? 999).compareTo(pos[b.id] ?? 999));
    }
    final hidden = all.where((c) => c.kind == _kind && c.hidden).toList();
    final expense = _kind == TransactionKind.expense;
    final budgetViews = (views ?? const <BudgetView>[])
        .where((v) => !v.category.hidden)
        .toList();

    final List<Widget> body;
    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(
                  categoriesAsync.error!,
                  action: 'load categories',
                ),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(categoriesProvider),
              ),
            ],
          ),
        ),
      ];
    } else if (!categoriesAsync.hasValue) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          ),
        ),
      ];
    } else {
      body = [
        if (expense && budgetViews.isNotEmpty) ...[
          FadeSlideIn(
            child: BudgetSummaryCard(
              totals: BudgetTotals.of(budgetViews),
              currency: currency,
              count: budgetViews.length,
            ),
          ),
          const _Section('Budgets'),
          for (final (i, v) in budgetViews.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 50 * (i + 1)),
                child: BudgetCard(
                  view: v,
                  currency: currency,
                  onTap: () => _editBudget(v.category, v.status.budget),
                ),
              ),
            ),
        ] else if (expense)
          FadeSlideIn(
            child: GlassCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  const VeloraMascot(
                    pose: MascotPose.budget,
                    size: 76,
                    halo: false,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Give your money a job', style: text.titleMedium),
                        Text(
                          'Tap “Set budget” on any category below. Velora '
                          'tracks the pace and what’s safe to spend each day.',
                          style: text.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Section(
          expense ? 'Expense categories' : 'Income categories',
          hint: 'Drag to reorder · tap to edit',
        ),
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            proxyDecorator: (child, _, _) => Material(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
            onReorderItem: (from, to) => _reorder(visible, from, to),
            children: [
              for (final (i, c) in visible.indexed)
                _CategoryRow(
                  key: ValueKey(c.id),
                  index: i,
                  category: c,
                  divider: i > 0,
                  subtitle: switch ((expense, budgetOf[c.id])) {
                    (true, final b?) =>
                      'Budget ${Money.short(b.amountMinor, currency)} '
                          '${b.period == BudgetPeriod.daily ? 'a day' : 'a ${b.period.unit}'}',
                    (true, null) => switch (lastMonth[c.id]) {
                      final m? when m > 0 =>
                        '${Money.format(m, currency)} last month',
                      _ => 'No budget',
                    },
                    (false, _) => null,
                  },
                  budgetAction: expense
                      ? _BudgetButton(
                          hasBudget: budgetOf[c.id] != null,
                          onTap: () => _editBudget(c, budgetOf[c.id]),
                        )
                      : null,
                  onTap: () => _edit(c, budgetOf[c.id]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CreateButton(label: 'Create a custom category', onTap: _create),
        if (hidden.isNotEmpty) ...[
          const _Section(
            'Hidden',
            hint: 'Not in the pickers · history keeps them',
          ),
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final (i, c) in hidden.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 66,
                        color: AppColors.hairline(0.06),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      leading: Opacity(
                        opacity: 0.5,
                        child: CategoryBadge(
                          icon: c.iconData,
                          color: c.colorValue,
                          size: 38,
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: text.titleMedium?.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _restore(c),
                        child: const Text('Show'),
                      ),
                      onTap: () => _edit(c, budgetOf[c.id]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ];
    }

    return SceneScaffold(
      eyebrow: 'Plan',
      title: 'Categories',
      actions: [
        RoundIconButton(
          icon: Icons.add_rounded,
          semanticLabel: 'New category',
          active: true,
          onTap: _create,
        ),
      ],
      onRefresh: () async {
        ref
          ..invalidate(categoriesProvider)
          ..invalidate(budgetsProvider)
          ..invalidate(budgetTransactionsProvider);
        await ref.read(categoriesProvider.future);
      },
      children: [
        Center(
          child: KindSwitcher(
            value: _kind,
            onChanged: (k) => setState(() => _kind = k),
          ),
        ),
        const SizedBox(height: 16),
        ...body,
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          if (hint != null)
            Text(hint!, style: text.labelMedium?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.index,
    required this.category,
    required this.divider,
    required this.subtitle,
    required this.budgetAction,
    required this.onTap,
  });

  final int index;
  final Category category;
  final bool divider;
  final String? subtitle;
  final Widget? budgetAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = category;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (divider)
            Divider(height: 1, indent: 66, color: AppColors.hairline(0.06)),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: 'Drag to reorder ${c.name}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  CategoryBadge(
                    icon: c.iconData,
                    color: c.colorValue,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 14),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: text.labelMedium),
                      ],
                    ),
                  ),
                  ?budgetAction,
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 17,
                    color: AppColors.textMuted,
                    semanticLabel: 'Edit ${c.name}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetButton extends StatelessWidget {
  const _BudgetButton({required this.hasBudget, required this.onTap});

  final bool hasBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hasBudget ? AppColors.accentBright : AppColors.sky;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hasBudget ? 'Budget' : 'Set budget',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontSize: 11, color: color),
          ),
        ),
      ),
    );
  }
}

/// A dashed "add" button that spans the width.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: CustomPaint(
          painter: _DashedBorder(color: AppColors.accentBright),
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: AppColors.accentBright),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 14, color: AppColors.accentBright),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(18),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// The category's budget inside its editor: what it is, or an offer to set
/// one.
class _BudgetLink extends StatelessWidget {
  const _BudgetLink({
    required this.budget,
    required this.currency,
    required this.onTap,
  });

  final Budget? budget;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = budget;
    return Material(
      color: AppColors.accent.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.pie_chart_rounded, color: AppColors.accentBright),
        title: Text(
          b == null
              ? 'Set a budget'
              : 'Budget: ${Money.short(b.amountMinor, currency)} '
                    '${b.period.label.toLowerCase()}',
          style: text.titleMedium?.copyWith(fontSize: 14),
        ),
        subtitle: Text(
          b == null
              ? 'Track the pace and what’s safe to spend'
              : 'Change the limit or period',
          style: text.labelMedium,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: AppColors.accentBright,
        ),
      ),
    );
  }
}
