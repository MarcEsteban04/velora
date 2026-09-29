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
import 'debt_editor_sheet.dart';
import 'debt_entry_sheet.dart';
import 'debt_style.dart';

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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: debt.kind.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    p.isPaidOff ? Icons.celebration_rounded : debt.kind.icon,
                    color: debt.kind.color,
                  ),
                ),
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
            ProgressBar(value: p.fraction, color: debt.kind.color, height: 8),
            const SizedBox(height: 4),
            Text(
              '${(p.fraction * 100).floor()}% paid of ${money(p.totalMinor)}',
              style: text.labelMedium,
            ),
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
                  paid ? 'Paid $amount' : 'Borrowed $amount',
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
