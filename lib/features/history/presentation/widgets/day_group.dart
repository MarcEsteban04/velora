import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/widgets/account_avatar.dart';
import '../../../transactions/domain/category.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/category_style.dart';

/// "Today", "Yesterday", or the weekday for the rest of this week, then
/// the date.
String dayTitle(DateTime day, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(day);
  return DateFormat('EEE, MMM d').format(day);
}

/// What can be done to a transaction from History.
class TransactionMenu {
  const TransactionMenu({
    required this.onEdit,
    required this.onRepeat,
    required this.onDelete,
  });

  final void Function(Transaction) onEdit;

  /// Logs the same thing again, now.
  final void Function(Transaction) onRepeat;
  final void Function(Transaction) onDelete;
}

/// One day: a header with the day's net and a timeline of its
/// transactions. The header folds the day away when [onToggle] is given.
class DayGroup extends StatelessWidget {
  const DayGroup({
    super.key,
    required this.day,
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.currency,
    required this.inMainCurrency,
    required this.hidden,
    required this.menu,
    this.collapsed = false,
    this.onToggle,
  });

  final DateTime day;

  /// Newest first.
  final List<Transaction> transactions;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final Currency currency;
  final bool Function(String accountId) inMainCurrency;
  final bool hidden;
  final TransactionMenu menu;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final flow = FlowSummary.of(transactions, inCurrency: inMainCurrency);
    final net = flow.netMinor;
    final hasFlow = flow.incomeMinor != 0 || flow.spentMinor != 0;
    final netColor = net < 0 ? AppColors.rust : AppColors.leafBright;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          if (onToggle != null)
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                color: AppColors.textMuted,
              ),
            ),
          if (onToggle != null) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayTitle(day, DateTime.now()),
                  style: text.titleMedium?.copyWith(fontSize: 17),
                ),
                Text(
                  DateFormat('MMMM d, y').format(day).toUpperCase(),
                  style: text.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (collapsed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('${transactions.length}', style: text.labelMedium),
            ),
          if (hasFlow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: netColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hidden
                    ? '${currency.symbol} ••••'
                    : '${net < 0 ? '−' : '+'}${Money.format(net.abs(), currency)}',
                style: text.labelMedium?.copyWith(color: netColor),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggle == null)
          header
        else
          Semantics(
            button: true,
            expanded: !collapsed,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle!();
              },
              child: header,
            ),
          ),
        Divider(height: 1, color: AppColors.hairline(0.08)),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      for (final (i, t) in transactions.indexed)
                        _TimelineEntry(
                          key: ValueKey(t.id),
                          transaction: t,
                          first: i == 0,
                          last: i == transactions.length - 1,
                          accounts: accounts,
                          categories: categories,
                          hidden: hidden,
                          menu: menu,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// A transaction on the day's timeline: its time, a dot on the line, and
/// its card. Swipe left to delete.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    super.key,
    required this.transaction,
    required this.first,
    required this.last,
    required this.accounts,
    required this.categories,
    required this.hidden,
    required this.menu,
  });

  final Transaction transaction;
  final bool first;
  final bool last;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final bool hidden;
  final TransactionMenu menu;

  static const _timeHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = transaction;
    final dot = switch (t.kind) {
      TransactionKind.expense => AppColors.rust,
      TransactionKind.income => AppColors.leafBright,
      TransactionKind.transfer => AppColors.sky,
    };

    return Dismissible(
      key: ValueKey('swipe-${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(top: _timeHeight, left: 24, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.rust.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.rust),
      ),
      onDismissed: (_) => menu.onDelete(t),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: CustomPaint(
                painter: _TimelinePainter(
                  first: first,
                  last: last,
                  dot: dot,
                  line: AppColors.hairline(0.12),
                  dotY: _timeHeight + 34,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _timeHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          DateFormat('h:mm a').format(t.occurredAt),
                          style: text.labelMedium?.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                    _TransactionCard(
                      transaction: t,
                      accounts: accounts,
                      categories: categories,
                      hidden: hidden,
                      menu: menu,
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

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.first,
    required this.last,
    required this.dot,
    required this.line,
    required this.dotY,
  });

  final bool first;
  final bool last;
  final Color dot;
  final Color line;
  final double dotY;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2 - 2;
    final y = dotY.clamp(0, size.height).toDouble();
    final paint = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x, first ? y : 0),
      Offset(x, last ? y : size.height),
      paint,
    );
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.first != first ||
      old.last != last ||
      old.dot != dot ||
      old.line != line;
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.accounts,
    required this.categories,
    required this.hidden,
    required this.menu,
  });

  final Transaction transaction;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final bool hidden;
  final TransactionMenu menu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = transaction;
    final account = accounts[t.accountId];
    final toAccount = t.toAccountId == null ? null : accounts[t.toAccountId];
    final category = t.categoryId == null ? null : categories[t.categoryId];
    final currency = Currencies.byCode(account?.currencyCode ?? 'USD');
    final isTransfer = t.kind == TransactionKind.transfer;

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (category?.iconData ?? Icons.category_rounded);
    final color = isTransfer
        ? TransactionKind.transfer.color
        : (category?.colorValue ?? AppColors.textMuted);
    final note = t.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final title = isTransfer ? 'Transfer' : (category?.name ?? t.kind.label);
    final subtitle = isTransfer
        ? '${account?.name ?? 'Account'} → ${toAccount?.name ?? 'Account'}'
        : hasNote
        ? note
        : null;

    final amount = hidden
        ? '${currency.symbol} ••••'
        : Money.format(t.amountMinor, currency);
    final signed = switch (t.kind) {
      TransactionKind.expense => '−$amount',
      TransactionKind.income => '+$amount',
      TransactionKind.transfer => amount,
    };
    final amountColor = switch (t.kind) {
      TransactionKind.income => AppColors.leafBright,
      TransactionKind.expense => AppColors.textPrimary,
      TransactionKind.transfer => AppColors.textSecondary,
    };

    return Material(
      color: AppColors.surface.withValues(alpha: 0.62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.hairline(0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => menu.onEdit(t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    signed,
                    style: text.titleMedium?.copyWith(color: amountColor),
                  ),
                  const SizedBox(height: 4),
                  _AccountChip(account: account),
                ],
              ),
              _MoreButton(transaction: t, menu: menu),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account});

  final Account? account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccountAvatar(account: a, size: 16),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            child: Text(
              a?.name ?? 'Account',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.transaction, required this.menu});

  final Transaction transaction;
  final TransactionMenu menu;

  Future<void> _open(BuildContext context) async {
    final text = Theme.of(context).textTheme;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (id, icon, label, color) in [
                ('edit', Icons.edit_rounded, 'Edit', AppColors.textPrimary),
                (
                  'repeat',
                  Icons.replay_rounded,
                  'Log again now',
                  AppColors.textPrimary,
                ),
                (
                  'delete',
                  Icons.delete_outline_rounded,
                  'Delete',
                  AppColors.rust,
                ),
              ])
                ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(
                    label,
                    style: text.titleMedium?.copyWith(color: color),
                  ),
                  onTap: () => Navigator.pop(context, id),
                ),
            ],
          ),
        ),
      ),
    );
    switch (choice) {
      case 'edit':
        menu.onEdit(transaction);
      case 'repeat':
        menu.onRepeat(transaction);
      case 'delete':
        menu.onDelete(transaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'More',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
      onPressed: () => _open(context),
    );
  }
}
