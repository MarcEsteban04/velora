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
import '../../accounts/data/account_repository.dart';
import '../../home/application/balance_privacy.dart';
import '../../transactions/application/transaction_providers.dart';
import '../application/planned_providers.dart';
import '../domain/planned_payment.dart';
import 'pay_planned_sheet.dart';
import 'planned_editor_sheet.dart';
import 'planned_style.dart';

/// One planned payment up close: when it's next, how it repeats, what it
/// has paid, and Pay, Skip, Edit, Stop and Delete.
abstract final class PlannedDetailSheet {
  static Future<void> show(BuildContext context, String plannedId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _Detail(plannedId: plannedId),
      );
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.plannedId});

  final String plannedId;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String yes,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.rust),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _skip(BuildContext context, PlannedPayment p) async {
    final toast = Toast.of(context);
    final actions = PlannedActions.of(context);
    HapticFeedback.selectionClick();
    try {
      await actions.skip(p);
      final next = p.nextAfter(p.nextDue);
      toast.show(
        next == null
            ? '${p.name} skipped'
            : 'Skipped · next ${DateFormat('MMM d').format(next)}',
        tone: ToastTone.info,
        action: ToastAction('Undo', () => actions.restore(p)),
      );
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'skip it'));
    }
  }

  Future<void> _stop(BuildContext context, PlannedPayment p) async {
    final ok = await _confirm(
      context,
      title: 'Stop ${p.name}?',
      body:
          'No more reminders or dates. What it has paid stays in your '
          'history.',
      yes: 'Stop',
    );
    if (!ok || !context.mounted) return;
    final toast = Toast.of(context);
    final actions = PlannedActions.of(context);
    try {
      await actions.stop(p);
      toast.show(
        '${p.name} stopped',
        tone: ToastTone.info,
        action: ToastAction('Undo', () => actions.restore(p)),
      );
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'stop it'));
    }
  }

  Future<void> _delete(BuildContext context, PlannedPayment p) async {
    final ok = await _confirm(
      context,
      title: 'Delete ${p.name}?',
      body: 'Its reminders go. Payments already logged stay in your history.',
      yes: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final toast = Toast.of(context);
    try {
      await PlannedActions.of(context).delete(p.id);
      toast.show('${p.name} deleted', tone: ToastTone.info);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'delete it'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(plannedProvider).value;
    final p = all?.where((x) => x.id == plannedId).firstOrNull;
    if (p == null) {
      // Deleted: close once this frame is done.
      if (all != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
      return const SizedBox(height: 120);
    }
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final account = accounts.where((a) => a.id == p.accountId).firstOrNull;
    final category = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final c = Currencies.byCode(account?.currencyCode ?? 'PHP');
    final hidden = ref.watch(balancesHiddenProvider);
    String money(int m) => hidden ? '${c.symbol}••••' : Money.format(m, c);
    final now = AppClock.now();
    final status = dueStatus(p, now);
    final history = ref.watch(plannedHistoryProvider(p.id)).value ?? const [];

    final stats = <(String, String)>[
      (p.isIncome ? 'Comes into' : 'Paid from', account?.name ?? 'An account'),
      ('Repeats', describeRepeat(p)),
      (
        'Reminder',
        switch (p.remindDays) {
          null => 'Off',
          0 => 'On the day, 9 AM',
          1 => '1 day before',
          final n => '$n days before',
        },
      ),
      if (p.autoLog) ('Logged', 'By itself on the day'),
      if (category != null) ('Category', category.name),
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
                PlannedBadge(planned: p, category: category, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      Text(
                        p.isIncome ? 'Planned income' : 'Planned payment',
                        style: text.labelMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => PlannedEditorSheet.show(context, planned: p),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              p.isDone ? 'DONE' : plannedDueLabel(p, now).toUpperCase(),
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
                color: p.isDone ? AppColors.leafBright : dueColor(status),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(p.amountMinor),
                style: text.displaySmall?.copyWith(fontSize: 30),
              ),
            ),
            if (!p.isDone)
              Text(
                DateFormat('EEEE, MMMM d, y').format(p.nextDue),
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
                          Text(label, style: text.labelMedium),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              value,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (p.isDone)
              PressableButton(
                label: 'Start again',
                icon: Icons.replay_rounded,
                height: 50,
                variant: PressableButtonVariant.light,
                onPressed: () => PlannedEditorSheet.show(context, planned: p),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PressableButton(
                      label: p.isIncome ? 'It came in' : 'Pay',
                      icon: Icons.check_circle_rounded,
                      height: 50,
                      onPressed: () => PayPlannedSheet.show(context, p),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PressableButton(
                      label: 'Skip',
                      icon: Icons.skip_next_rounded,
                      height: 50,
                      variant: PressableButtonVariant.light,
                      onPressed: () => _skip(context, p),
                    ),
                  ),
                ],
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'HISTORY',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              for (final t in history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        p.isIncome
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: p.isIncome
                            ? AppColors.leafBright
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          DateFormat('MMM d, y').format(t.occurredAt),
                          style: text.titleMedium?.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        money(t.amountMinor),
                        style: text.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!p.isDone && p.repeat != PlannedRepeat.once)
                  TextButton(
                    onPressed: () => _stop(context, p),
                    child: const Text('Stop repeating'),
                  ),
                TextButton(
                  onPressed: () => _delete(context, p),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
