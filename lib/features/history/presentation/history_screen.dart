import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import 'widgets/day_group.dart';
import 'widgets/history_filter.dart';
import 'widgets/month_calendar.dart';

enum _View { list, calendar }

/// Every transaction, a month at a time, as a timeline of days or as a
/// calendar. Search, filter by type, account and category, fold days away,
/// and edit, log again or delete (with Undo) from each card.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _month = monthKey(DateTime.now());
  _View _view = _View.list;
  HistoryFilter _filter = const HistoryFilter();
  bool _searching = false;
  String _query = '';

  /// The day open in the calendar. Null picks a sensible one.
  DateTime? _day;

  /// Days folded away in the list.
  final _collapsed = <DateTime>{};

  /// Deleted rows waiting for the server. They're hidden right away,
  /// because a dismissed row must leave the tree immediately.
  final _removed = <String>{};

  bool get _isCurrentMonth => _month == monthKey(DateTime.now());

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(monthKey(DateTime.now()))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _month = next;
      _day = null;
    });
  }

  Future<void> _delete(Transaction t) async {
    setState(() => _removed.add(t.id));
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    try {
      await actions.delete(t.id);
      HapticFeedback.mediumImpact();
      toast.show(
        'Transaction deleted',
        tone: ToastTone.info,
        icon: Icons.delete_outline_rounded,
        action: ToastAction('Undo', () => actions.create(t.toDraft())),
      );
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'delete that'),
        tone: ToastTone.error,
      );
      if (mounted) setState(() => _removed.remove(t.id));
    }
  }

  /// Logs the same transaction again, now.
  Future<void> _repeat(Transaction t) async {
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    final currency = Currencies.byCode(
      ref
              .read(accountsProvider)
              .value
              ?.where((a) => a.id == t.accountId)
              .firstOrNull
              ?.currencyCode ??
          ref.read(mainCurrencyProvider).code,
    );
    try {
      final d = t.toDraft();
      final saved = await actions.create(
        TransactionDraft(
          kind: d.kind,
          amountMinor: d.amountMinor,
          accountId: d.accountId,
          toAccountId: d.toAccountId,
          toAmountMinor: d.toAmountMinor,
          categoryId: d.categoryId,
          note: d.note,
          occurredAt: DateTime.now(),
        ),
      );
      HapticFeedback.mediumImpact();
      toast.show(
        'Logged again · ${Money.format(t.amountMinor, currency)}',
        icon: Icons.replay_rounded,
        action: ToastAction('Undo', () => actions.delete(saved.id)),
      );
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'log that'),
        tone: ToastTone.error,
      );
    }
  }

  void _edit(Transaction t) =>
      Navigator.of(context).push(TransactionEntryScreen.route(existing: t));

  Future<void> _openFilter(List<Account> accounts, List<Category> cats) async {
    final picked = await HistoryFilter.edit(
      context,
      current: _filter,
      accounts: accounts,
      categories: cats,
    );
    if (picked != null) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(monthTransactionsProvider(_month));
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final hidden = ref.watch(balancesHiddenProvider);
    final main = ref.watch(mainCurrencyProvider);

    final accountById = {for (final a in accounts) a.id: a};
    final categoryById = {for (final c in categories) c.id: c};
    bool inMain(String id) => accountById[id]?.currencyCode == main.code;

    final all = (async.value ?? const <Transaction>[])
        .where((t) => !_removed.contains(t.id))
        .toList();
    final q = _query.toLowerCase();
    final visible = all.where((t) {
      if (!_filter.matches(t)) return false;
      if (q.isEmpty) return true;
      final haystack = [
        t.note ?? '',
        categoryById[t.categoryId]?.name ?? '',
        accountById[t.accountId]?.name ?? '',
        accountById[t.toAccountId]?.name ?? '',
        Money.format(t.amountMinor, main),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
    final summary = FlowSummary.of(visible, inCurrency: inMain);

    final byDay = <DateTime, List<Transaction>>{};
    for (final t in visible) {
      byDay.putIfAbsent(DateUtils.dateOnly(t.occurredAt), () => []).add(t);
    }

    String fmt(int minor) =>
        hidden ? '${main.symbol} ••••' : Money.format(minor, main);
    final menu = TransactionMenu(
      onEdit: _edit,
      onRepeat: _repeat,
      onDelete: _delete,
    );

    Widget group(
      DateTime day,
      List<Transaction> txns, {
      bool foldable = true,
    }) => DayGroup(
      key: ValueKey(day),
      day: day,
      transactions: txns,
      accounts: accountById,
      categories: categoryById,
      currency: main,
      inMainCurrency: inMain,
      hidden: hidden,
      menu: menu,
      collapsed: foldable && _collapsed.contains(day),
      onToggle: foldable
          ? () => setState(
              () => _collapsed.contains(day)
                  ? _collapsed.remove(day)
                  : _collapsed.add(day),
            )
          : null,
    );

    final filtered = !_filter.isEmpty || q.isNotEmpty;
    final List<Widget> body;
    if (async.isLoading && !async.hasValue) {
      body = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.leafBright),
          ),
        ),
      ];
    } else if (async.hasError && !async.hasValue) {
      body = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(async.error!, action: 'load your history'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    ref.invalidate(monthTransactionsProvider(_month)),
              ),
            ],
          ),
        ),
      ];
    } else if (_view == _View.calendar) {
      final activity = <DateTime, DayActivity>{
        for (final e in byDay.entries)
          e.key: () {
            final f = FlowSummary.of(e.value, inCurrency: inMain);
            return DayActivity(
              spentMinor: f.spentMinor,
              incomeMinor: f.incomeMinor,
              count: e.value.length,
            );
          }(),
      };
      final today = DateUtils.dateOnly(DateTime.now());
      final day =
          _day ??
          (_isCurrentMonth
              ? today
              : (byDay.keys.isEmpty
                    ? DateTime(_month.year, _month.month + 1, 0)
                    : byDay.keys.first));
      final dayTxns = byDay[day] ?? const <Transaction>[];
      body = [
        MonthCalendar(
          month: _month,
          activity: activity,
          selected: day,
          currency: main,
          hidden: hidden,
          onSelect: (d) => setState(() => _day = d),
          onSwipe: _shiftMonth,
        ),
        if (dayTxns.isEmpty)
          _EmptyDay(
            day: day,
            onLog: () =>
                Navigator.of(context)
                    .push(TransactionEntryScreen.route(day: day)),
          )
        else
          group(day, dayTxns, foldable: false),
      ];
    } else if (visible.isEmpty) {
      body = [_EmptyHistory(month: _month, filtered: filtered)];
    } else {
      body = [for (final e in byDay.entries) group(e.key, e.value)];
    }

    return RefreshIndicator(
      color: AppColors.leafBright,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () async {
        ref.invalidate(monthTransactionsProvider(_month));
        await ref.read(monthTransactionsProvider(_month).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 20,
          20,
          FloatingNavBar.reservedHeight(context),
        ),
        children: [
          FadeSlideIn(
            child: Row(
              children: [
                Expanded(child: Text('History', style: text.displaySmall)),
                RoundIconButton(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  semanticLabel: _searching ? 'Close search' : 'Search',
                  active: _searching,
                  onTap: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _query = '';
                  }),
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: _view == _View.list
                      ? Icons.calendar_month_rounded
                      : Icons.view_agenda_rounded,
                  semanticLabel: _view == _View.list
                      ? 'Calendar view'
                      : 'List view',
                  active: _view == _View.calendar,
                  onTap: () => setState(
                    () => _view = _view == _View.list
                        ? _View.calendar
                        : _View.list,
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    RoundIconButton(
                      icon: Icons.tune_rounded,
                      semanticLabel: _filter.isEmpty
                          ? 'Filter'
                          : 'Filter, ${_filter.count} on',
                      active: !_filter.isEmpty,
                      onTap: () => _openFilter(accounts, categories),
                    ),
                    if (!_filter.isEmpty)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.ember,
                          ),
                          child: Text(
                            '${_filter.count}',
                            style: text.labelMedium?.copyWith(
                              fontSize: 10,
                              color: AppColors.onBrand,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: text.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search notes, categories, accounts',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (!_filter.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ActiveFilters(
                filter: _filter,
                accounts: accountById,
                categories: categoryById,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _MonthBar(
              month: _month,
              canGoNext: !_isCurrentMonth,
              onShift: _shiftMonth,
              income: fmt(summary.incomeMinor),
              spent: fmt(summary.spentMinor),
              net:
                  '${summary.netMinor < 0 ? '−' : ''}${fmt(summary.netMinor.abs())}',
              filtered: filtered,
            ),
          ),
          const SizedBox(height: 4),
          ...body,
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.canGoNext,
    required this.onShift,
    required this.income,
    required this.spent,
    required this.net,
    required this.filtered,
  });

  final DateTime month;
  final bool canGoNext;
  final ValueChanged<int> onShift;
  final String income;
  final String spent;
  final String net;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM y').format(month),
                      style: text.titleMedium,
                    ),
                    if (filtered)
                      Text(
                        'Filtered',
                        style: text.labelMedium?.copyWith(
                          fontSize: 10,
                          color: AppColors.ember,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: canGoNext ? () => onShift(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              _Stat(label: 'In', value: income, color: AppColors.leafBright),
              _Stat(
                label: 'Out',
                value: spent,
                color: TransactionKind.expense.color,
              ),
              _Stat(label: 'Net', value: net, color: AppColors.textPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleMedium?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// The filters in use, each removable with a tap.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.accounts,
    required this.categories,
    required this.onChanged,
  });

  final HistoryFilter filter;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <(String, Color, VoidCallback)>[
      if (filter.kind case final k?)
        (
          switch (k) {
            TransactionKind.expense => 'Expenses',
            TransactionKind.income => 'Income',
            TransactionKind.transfer => 'Transfers',
          },
          k.color,
          () => onChanged(filter.copyWith(kind: () => null)),
        ),
      for (final id in filter.accountIds)
        (
          accounts[id]?.name ?? 'Account',
          AppColors.sky,
          () => onChanged(
            filter.copyWith(accountIds: {...filter.accountIds}..remove(id)),
          ),
        ),
      for (final id in filter.categoryIds)
        (
          categories[id]?.name ?? 'Category',
          categories[id]?.colorValue ?? AppColors.textMuted,
          () => onChanged(
            filter.copyWith(categoryIds: {...filter.categoryIds}..remove(id)),
          ),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, color, remove) in chips)
          InputChip(
            label: Text(label),
            onDeleted: remove,
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            labelStyle: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.textPrimary),
            backgroundColor: color.withValues(alpha: 0.16),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day, required this.onLog});

  final DateTime day;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dayTitle(day, DateTime.now()), style: text.titleMedium),
                  Text(
                    'Nothing logged on ${DateFormat('MMMM d').format(day)}',
                    style: text.labelMedium,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log for this day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.month, required this.filtered});

  final DateTime month;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        child: Column(
          children: [
            const VeloraMascot(pose: MascotPose.coin, size: 110, halo: false),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Nothing matches'
                  : 'Nothing logged in ${DateFormat('MMMM').format(month)}',
              style: text.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Try another filter or search.'
                  : 'Tap + to log an expense or income.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
