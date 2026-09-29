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
import '../application/owed_providers.dart';
import '../domain/owed.dart';
import 'owed_editor_sheet.dart';
import 'owed_entry_sheet.dart';
import 'owed_style.dart';

/// One person up close: what they still owe, what's come back, when it's
/// due, the history, and Paid back, Lent more, a reminder, Edit and Delete.
abstract final class OwedDetailSheet {
  static Future<void> show(BuildContext context, String owedId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _OwedDetail(owedId: owedId),
      );
}

class _OwedDetail extends ConsumerWidget {
  const _OwedDetail({required this.owedId});

  final String owedId;

  Future<void> _delete(BuildContext context, Owed owed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Delete ${owed.name}?'),
        content: const Text(
          'Its history goes too. Anything already logged in your accounts '
          'stays.',
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
      await OwedActions.of(context).delete(owed.id);
      toast.show('${owed.name} deleted', tone: ToastTone.info);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'delete that'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(owedProgressProvider);
    final p = list?.where((o) => o.owed.id == owedId).firstOrNull;
    if (p == null) {
      // Deleted: close once this frame is done.
      if (list != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
      return const SizedBox(height: 120);
    }
    final owed = p.owed;
    final c = Currencies.byCode(owed.currencyCode);
    final hidden = ref.watch(balancesHiddenProvider);
    String money(int m) => hidden ? '${c.symbol}••••' : Money.format(m, c);
    final now = AppClock.now();
    final overdue = p.isOverdue(now);

    final stats = <(String, String)>[
      ('Lent', money(p.lentMinor)),
      ('Paid back', money(p.backMinor)),
      if (p.lentOn case final d?)
        ('First lent', DateFormat('MMM d, y').format(d)),
      if (owed.dueOn case final d? when !p.isSettled)
        ('Pay back by', DateFormat('EEE, MMM d').format(d)),
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
                OwedAvatar(owed: owed, size: 48, settled: p.isSettled),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owed.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      if (owed.note case final n? when n.isNotEmpty)
                        Text(
                          n,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () =>
                      OwedEditorSheet.show(context, currency: c, owed: owed),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              p.isSettled ? 'ALL PAID BACK' : 'STILL OWES YOU',
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                color: p.isSettled ? AppColors.leafBright : null,
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
            ProgressBar(value: p.fraction, color: owed.color, height: 8),
            const SizedBox(height: 4),
            Text(
              '${(p.fraction * 100).floor()}% paid back of ${money(p.lentMinor)}',
              style: text.labelMedium,
            ),
            if (overdue) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.rust.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppColors.rust,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payBackLabel(owed.dueOn!, now),
                        style: text.titleMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
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
                    label: 'Paid back',
                    icon: Icons.check_circle_rounded,
                    height: 50,
                    onPressed: p.isSettled
                        ? null
                        : () => OwedEntrySheet.show(
                            context,
                            progress: p,
                            mode: OwedEntryMode.paidBack,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PressableButton(
                    label: 'Lent more',
                    icon: Icons.add_circle_rounded,
                    height: 50,
                    variant: PressableButtonVariant.light,
                    onPressed: () => OwedEntrySheet.show(
                      context,
                      progress: p,
                      mode: OwedEntryMode.lentMore,
                    ),
                  ),
                ),
              ],
            ),
            if (!p.isSettled) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final toast = Toast.of(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: owedReminder(p, Money.format(p.remainingMinor, c)),
                    ),
                  );
                  HapticFeedback.selectionClick();
                  toast.show(
                    'Reminder copied. Paste it in your chat with ${owed.name}.',
                    icon: Icons.content_copy_rounded,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Copy a reminder'),
              ),
            ],
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
                      await OwedActions.of(context).undo(e);
                      toast.show('Removed', tone: ToastTone.info);
                    } on Object catch (error) {
                      toast.error(friendlyError(error, action: 'remove that'));
                    }
                  },
                ),
            ],
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _delete(context, owed),
                style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                child: const Text('Delete'),
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

  final OwedEntry entry;
  final String amount;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final back = entry.isRepayment;
    final color = back ? AppColors.leafBright : AppColors.ember;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            back ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  back ? 'Paid back $amount' : 'Lent $amount',
                  style: text.titleMedium?.copyWith(fontSize: 14),
                ),
                Text(
                  [
                    DateFormat('MMM d, y').format(entry.occurredAt),
                    if (entry.transactionId != null)
                      back ? 'logged as income' : 'logged as an expense',
                    if (entry.note case final n? when n.isNotEmpty) n,
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
