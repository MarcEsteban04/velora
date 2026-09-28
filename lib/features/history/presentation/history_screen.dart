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
import '../../transactions/presentation/transaction_details_sheet.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import '../../receipts/presentation/widgets/receipt_attachment.dart';
import '../../receipts/presentation/widgets/receipt_image.dart';
import 'widgets/day_group.dart';
import 'widgets/history_filter.dart';
import 'widgets/month_calendar.dart';
import '../../../core/time/app_clock.dart';

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
  DateTime _month = monthKey(AppClock.now());
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

  bool get _isCurrentMonth => _month == monthKey(AppClock.now());

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(monthKey(AppClock.now()))) return;
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
          occurredAt: AppClock.now(),
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

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(selected: _month),
    );
    if (picked != null && picked != _month) {
      HapticFeedback.selectionClick();
      setState(() {
        _month = picked;
        _day = null;
      });
    }
  }

  /// Shows the receipt (to replace or remove), or adds one.
  Future<void> _receipt(Transaction t) async {
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    Future<void> attach() async {
      final photo = await chooseReceiptPhoto(context, ref);
      if (photo == null) return;
      try {
        await actions.attachReceipt(t.id, photo);
        toast.show('Receipt attached', icon: Icons.attach_file_rounded);
      } on Object catch (error) {
        toast.error(friendlyError(error, action: 'upload the receipt'));
      }
    }

    if (!t.hasReceipt) return attach();
    final action = await ReceiptViewer.show(
      context,
      path: t.receiptPath,
      canEdit: true,
    );
    if (!mounted) return;
    switch (action) {
      case ReceiptViewerAction.replace:
        await attach();
      case ReceiptViewerAction.remove:
        try {
          await actions.removeReceipt(t);
          toast.show(
            'Receipt removed',
            tone: ToastTone.info,
            icon: Icons.delete_outline_rounded,
          );
        } on Object catch (error) {
          toast.error(friendlyError(error, action: 'remove the receipt'));
        }
      case null:
        break;
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

    final byDay = <DateTime, List<Transaction>>{};
    for (final t in visible) {
      byDay.putIfAbsent(DateUtils.dateOnly(t.occurredAt), () => []).add(t);
    }

    final menu = TransactionMenu(
      onView: (t) => TransactionDetailsSheet.show(context, t),
      onEdit: _edit,
      onRepeat: _repeat,
      onDelete: _delete,
      onReceipt: _receipt,
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
      final today = DateUtils.dateOnly(AppClock.now());
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
          canGoNext: !_isCurrentMonth,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('History', style: text.displaySmall),
                      _MonthLabel(month: _month, onTap: _pickMonth),
                    ],
                  ),
                ),
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
          const SizedBox(height: 6),
          ...body,
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
                  Text(dayTitle(day, AppClock.now()), style: text.titleMedium),
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

/// The month on show, under the title. Tap to pick another.
class _MonthLabel extends StatelessWidget {
  const _MonthLabel({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${DateFormat('MMMM y').format(month)}, change month',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  DateFormat('MMMM y').format(month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge,
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last two years of months to jump to.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.selected});

  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = AppClock.now();
    final months = [
      for (var i = 0; i < 24; i++) DateTime(now.year, now.month - i),
    ];
    final years = <int, List<DateTime>>{};
    for (final m in months) {
      years.putIfAbsent(m.year, () => []).add(m);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick a month', style: text.headlineSmall),
              for (final MapEntry(key: year, value: list) in years.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
                  child: Text(
                    '$year',
                    style: text.labelMedium?.copyWith(letterSpacing: 1.4),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in list)
                      ChoiceChip(
                        label: Text(DateFormat('MMM').format(m)),
                        selected: m == selected,
                        showCheckmark: false,
                        onSelected: (_) => Navigator.pop(context, m),
                        labelStyle: text.labelMedium?.copyWith(
                          fontSize: 13,
                          color: m == selected
                              ? AppColors.onBrand
                              : AppColors.textSecondary,
                        ),
                        selectedColor: AppColors.leaf,
                        backgroundColor: AppColors.surface.withValues(
                          alpha: 0.6,
                        ),
                        side: BorderSide(color: AppColors.hairline(0.08)),
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
