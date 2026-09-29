import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/progress_visuals.dart';
import '../../home/application/balance_privacy.dart';
import '../application/debt_providers.dart';
import '../domain/debt.dart';
import 'debt_bill_sheet.dart';
import 'debt_editor_sheet.dart';
import 'debt_entry_sheet.dart';
import 'debt_style.dart';
import 'scan_debt_screen.dart';

/// One debt up close: what's left, what's been paid, when it's due, its
/// history, and Pay, Borrowed more, Edit and Delete.
abstract final class DebtDetailSheet {
  static Future<void> show(BuildContext context, String debtId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DebtDetail(debtId: debtId),
      );
}

class _DebtDetail extends ConsumerWidget {
  const _DebtDetail({required this.debtId});

  final String debtId;

  Future<void> _delete(BuildContext context, Debt debt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Delete ${debt.name}?'),
        content: const Text(
          'Its payment history goes too. Expenses already logged from your '
          'accounts stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rust),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final toast = Toast.of(context);
    try {
      await DebtActions.of(context).delete(debt.id);
      toast.show('${debt.name} deleted', tone: ToastTone.info);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'delete the debt'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(debtProgressProvider);
    final p = list?.where((d) => d.debt.id == debtId).firstOrNull;
    if (p == null) {
      // Deleted: close once this frame is done.
      if (list != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
      return const SizedBox(height: 120);
    }
    final debt = p.debt;
    final c = Currencies.byCode(debt.currencyCode);
    final hidden = ref.watch(balancesHiddenProvider);
    String money(int m) => hidden ? '${c.symbol}••••' : Money.format(m, c);
    final now = AppClock.now();

    final stats = <(String, String)>[
      ('Paid so far', money(p.paidMinor)),
      if (p.borrowedMinor > 0) ('Borrowed since', money(p.borrowedMinor)),
      if (debt.monthlyMinor case final m?) ('Monthly', money(m)),
      if (p.nextDue case final d? when !p.isPaidOff)
        ('Next due', DateFormat('EEE, MMM d').format(d)),
      if (p.monthsLeft case final n?)
        ('To go', n == 1 ? 'Last payment' : 'About $n months'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DebtBadge(debt: debt, size: 48, paidOff: p.isPaidOff),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      Text(debt.kind.label, style: text.labelMedium),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () =>
                      DebtEditorSheet.show(context, currency: c, debt: debt),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              p.isPaidOff ? 'PAID OFF' : 'LEFT TO PAY',
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                color: p.isPaidOff ? AppColors.leafBright : null,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(p.remainingMinor),
                style: text.displaySmall?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 8),
            ProgressBar(value: p.fraction, color: debt.color, height: 8),
            const SizedBox(height: 4),
            Text(
              '${(p.fraction * 100).floor()}% paid of ${money(p.totalMinor)}',
              style: text.labelMedium,
            ),
            if (debt.kind.isCreditLine) ...[
              const SizedBox(height: 14),
              _CreditPanel(progress: p, money: money, now: now),
              const SizedBox(height: 14),
              _BillsPanel(progress: p, money: money, now: now),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline(0.07)),
              ),
              child: Column(
                children: [
                  for (final (label, value) in stats)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                      child: Row(
                        children: [
                          Expanded(child: Text(label, style: text.labelMedium)),
                          Text(
                            value,
                            style: text.titleMedium?.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PressableButton(
                    label: 'Pay',
                    icon: Icons.check_circle_rounded,
                    height: 50,
                    onPressed: p.isPaidOff
                        ? null
                        : () => DebtEntrySheet.show(
                            context,
                            progress: p,
                            mode: DebtEntryMode.pay,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PressableButton(
                    label: 'Borrowed more',
                    icon: Icons.add_circle_rounded,
                    height: 50,
                    variant: PressableButtonVariant.light,
                    onPressed: () => DebtEntrySheet.show(
                      context,
                      progress: p,
                      mode: DebtEntryMode.borrow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(ScanDebtScreen.route(debt.id));
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.document_scanner_rounded, size: 18),
              label: Text(
                debt.kind.isCreditLine
                    ? 'Scan a purchase or bill'
                    : 'Scan a screenshot',
              ),
            ),
            if (p.entries.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'HISTORY',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              for (final e in p.entries)
                _EntryRow(
                  entry: e,
                  amount: money(e.amountMinor.abs()),
                  onUndo: () async {
                    final toast = Toast.of(context);
                    HapticFeedback.selectionClick();
                    try {
                      await DebtActions.of(context).undo(e);
                      toast.show(
                        e.isPayment ? 'Payment removed' : 'Removed',
                        tone: ToastTone.info,
                      );
                    } on Object catch (error) {
                      toast.error(friendlyError(error, action: 'remove that'));
                    }
                  },
                ),
            ],
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _delete(context, debt),
                style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                child: const Text('Delete debt'),
              ),
            ),
            if (!p.isPaidOff && p.nextDue != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  dueLabel(p.nextDue!, now),
                  textAlign: TextAlign.center,
                  style: text.labelMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.amount,
    required this.onUndo,
  });

  final DebtEntry entry;
  final String amount;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paid = entry.isPayment;
    final color = paid ? AppColors.leafBright : AppColors.rust;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            paid ? Icons.south_rounded : Icons.north_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid
                      ? 'Paid $amount'
                      : (entry.installments ?? 1) > 1
                      ? 'Bought $amount · ${entry.installments} months'
                      : 'Borrowed $amount',
                  style: text.titleMedium?.copyWith(fontSize: 14),
                ),
                Text(
                  [
                    DateFormat('MMM d, y').format(entry.occurredAt),
                    if (entry.transactionId != null) 'logged as an expense',
                    if (entry.note case final n? when n.isNotEmpty && !paid) n,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onUndo,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A credit line at a glance, like the pay-later app's own page: the
/// limit, what's available, and what needs paying now.
class _CreditPanel extends StatelessWidget {
  const _CreditPanel({
    required this.progress,
    required this.money,
    required this.now,
  });

  final DebtProgress progress;
  final String Function(int minor) money;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final limit = p.debt.creditLimitMinor;
    final due = p.dueNowMinor;
    final used = p.usedFraction;

    Widget stat(String label, String value, {Color? color, String? sub}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: text.labelMedium?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: text.titleMedium?.copyWith(fontSize: 16, color: color),
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(fontSize: 10),
                ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              stat(
                'Total credit',
                limit == null ? 'Not set' : money(limit),
                sub: limit == null ? 'Add it with Edit' : null,
              ),
              stat(
                'Available',
                p.availableMinor == null ? '—' : money(p.availableMinor!),
                color: AppColors.leafBright,
              ),
              stat(
                'Need to pay',
                due == null ? '—' : money(due),
                color: (due ?? 0) > 0 ? AppColors.ember : null,
                sub: due == null
                    ? 'Scan your bill'
                    : due == 0
                    ? 'All settled'
                    : [
                        if (p.dueOn != null) dueLabel(p.dueOn!, now),
                        if (!p.dueFromBill) 'estimate',
                      ].join(' · '),
              ),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: 10),
            ProgressBar(
              value: used,
              color: used > 0.85 ? AppColors.rust : p.debt.color,
              height: 6,
            ),
            const SizedBox(height: 4),
            Text(
              '${(used * 100).round()}% of your credit used',
              style: text.labelMedium?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// A credit line's bills, like the app's "My Bill": each month's amount,
/// due date and whether it's paid. Tap one to pay it; the pencil edits it.
class _BillsPanel extends StatelessWidget {
  const _BillsPanel({
    required this.progress,
    required this.money,
    required this.now,
  });

  final DebtProgress progress;
  final String Function(int minor) money;
  final DateTime now;

  /// Paid bills kept in view, newest first.
  static const _paidShown = 2;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final unpaid = p.bills.where((b) => !b.isPaid).toList();
    final paid = p.bills.reversed
        .where((b) => b.isPaid)
        .take(_paidShown)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'BILLS',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            if (unpaid.length > 1)
              Text(
                '${money(p.billsLeftMinor)} in ${unpaid.length} bills',
                style: text.labelMedium?.copyWith(fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (p.bills.isEmpty)
          Text(
            'Add each month’s bill from “My Bill” in ${p.debt.name}, or scan '
            'the list, to see what’s due when.',
            style: text.labelMedium,
          ),
        for (final b in [...unpaid, ...paid])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BillRow(
              status: b,
              money: money,
              now: now,
              onTap: b.isPaid
                  ? () => DebtBillSheet.show(context, progress: p, bill: b.bill)
                  : () => DebtEntrySheet.show(
                      context,
                      progress: p,
                      mode: DebtEntryMode.pay,
                      bill: b,
                    ),
              onEdit: () =>
                  DebtBillSheet.show(context, progress: p, bill: b.bill),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => DebtBillSheet.show(context, progress: p),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add a bill'),
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.status,
    required this.money,
    required this.now,
    required this.onTap,
    required this.onEdit,
  });

  final BillStatus status;
  final String Function(int minor) money;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = status;
    final overdue = s.isOverdue(now);
    final (String tag, Color color) = s.isPaid
        ? ('Paid', AppColors.leafBright)
        : overdue
        ? ('Overdue', AppColors.rust)
        : s.paidMinor > 0
        ? ('${money(s.leftMinor)} left', AppColors.ember)
        : ('Unpaid', AppColors.ember);

    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline(0.07)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM').format(s.bill.month),
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        tag,
                        style: text.labelMedium?.copyWith(
                          fontSize: 10,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Due ${DateFormat('d MMM y').format(s.bill.dueOn)}',
                      style: text.labelMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                money(s.bill.amountMinor),
                style: text.titleMedium?.copyWith(
                  fontSize: 16,
                  color: s.isPaid ? AppColors.textMuted : null,
                  decoration: s.isPaid ? TextDecoration.lineThrough : null,
                ),
              ),
              IconButton(
                tooltip: 'Edit bill',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
