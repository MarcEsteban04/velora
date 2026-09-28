import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/data/profile_repository.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../../core/widgets/island_toast.dart';

/// Every transaction, one month at a time: a summary card, kind filters and
/// search, grouped by day. Swipe to delete (with Undo) and tap to edit.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _month = monthKey(DateTime.now());
  TransactionKind? _filter;
  bool _searching = false;
  String _query = '';

  /// Rows swiped away and waiting for the server. They're hidden right away,
  /// because a dismissed row must leave the tree immediately.
  final _removed = <String>{};

  bool get _isCurrentMonth => _month == monthKey(DateTime.now());

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
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
      // The delete failed, so bring the row back.
      if (mounted) setState(() => _removed.remove(t.id));
    }
  }

  String _dayLabel(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(monthTransactionsProvider(_month));
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final hidden = ref.watch(balancesHiddenProvider);
    final main = Currencies.byCode(
      ref.watch(profileProvider).value?.currencyCode ?? 'USD',
    );

    final accountById = {for (final a in accounts) a.id: a};
    final categoryById = {for (final c in categories) c.id: c};
    bool inMain(String id) => accountById[id]?.currencyCode == main.code;

    final all = async.value ?? const <Transaction>[];
    final summary = FlowSummary.of(all, inCurrency: inMain);
    final q = _query.toLowerCase();
    final visible = all.where((t) {
      if (_removed.contains(t.id)) return false;
      if (_filter != null && t.kind != _filter) return false;
      if (q.isEmpty) return true;
      final haystack = [
        t.note ?? '',
        categoryById[t.categoryId]?.name ?? '',
        accountById[t.accountId]?.name ?? '',
        accountById[t.toAccountId]?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();

    final byDay = <DateTime, List<Transaction>>{};
    for (final t in visible) {
      byDay.putIfAbsent(DateUtils.dateOnly(t.occurredAt), () => []).add(t);
    }

    String fmt(int minor) =>
        hidden ? '${main.symbol} ••••' : Money.format(minor, main);

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
          const SizedBox(height: 18),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _shiftMonth(-1),
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
                        onPressed: _isCurrentMonth
                            ? null
                            : () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Stat(
                        label: 'In',
                        value: fmt(summary.incomeMinor),
                        color: AppColors.leafBright,
                      ),
                      _Stat(
                        label: 'Out',
                        value: fmt(summary.spentMinor),
                        color: TransactionKind.expense.color,
                      ),
                      _Stat(
                        label: 'Net',
                        value:
                            '${summary.netMinor < 0 ? '−' : ''}${fmt(summary.netMinor.abs())}',
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, kind) in [
                  ('All', null),
                  ('Expenses', TransactionKind.expense),
                  ('Income', TransactionKind.income),
                  ('Transfers', TransactionKind.transfer),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                      showCheckmark: false,
                      labelStyle: text.labelMedium?.copyWith(
                        fontSize: 13,
                        color: _filter == kind
                            ? AppColors.night
                            : AppColors.textSecondary,
                      ),
                      selectedColor: kind?.color ?? AppColors.leafBright,
                      backgroundColor: AppColors.surface.withValues(alpha: 0.6),
                      side: BorderSide(color: AppColors.hairline(0.08)),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (async.isLoading && !async.hasValue)
            Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.leafBright),
              ),
            )
          else if (async.hasError && !async.hasValue)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GlassCard(
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
            )
          else if (visible.isEmpty)
            _EmptyHistory(
              month: _month,
              filtered: _filter != null || q.isNotEmpty,
            )
          else
            for (final entry in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(entry.key),
                        style: text.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final day = FlowSummary.of(
                          entry.value,
                          inCurrency: inMain,
                        );
                        if (day.incomeMinor == 0 && day.spentMinor == 0) {
                          return const SizedBox.shrink();
                        }
                        final net = day.netMinor;
                        return Text(
                          '${net < 0 ? '−' : '+'}${fmt(net.abs())}',
                          style: text.labelMedium?.copyWith(
                            color: net < 0
                                ? AppColors.textSecondary
                                : AppColors.leafBright,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                radius: 24,
                child: Column(
                  children: [
                    for (final (i, t) in entry.value.indexed) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 68,
                          color: AppColors.hairline(0.06),
                        ),
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          color: AppColors.rust.withValues(alpha: 0.25),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.rust,
                          ),
                        ),
                        onDismissed: (_) => _delete(t),
                        child: TransactionTile(
                          transaction: t,
                          accounts: accountById,
                          categories: categoryById,
                          hidden: hidden,
                          onTap: () => Navigator.of(context)
                              .push(TransactionEntryScreen.route(existing: t)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleMedium?.copyWith(color: color)),
          ),
        ],
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
