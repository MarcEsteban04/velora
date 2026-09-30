import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../accounts/data/account_repository.dart';
import '../../app_lock/application/app_lock_controller.dart';
import '../application/planned_providers.dart';
import '../data/planned_reminders.dart';
import '../domain/planned_payment.dart';

/// Keeps planned payments running by themselves once the app is unlocked:
/// phone reminders follow the list whenever it changes, and payments set
/// to log themselves are logged on (or after) their dates.
class PlannedAutopilot extends ConsumerStatefulWidget {
  const PlannedAutopilot({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlannedAutopilot> createState() => _PlannedAutopilotState();
}

class _PlannedAutopilotState extends ConsumerState<PlannedAutopilot> {
  bool _autoLogged = false;

  /// At most this many missed dates per plan are logged at once, so a long
  /// break doesn't flood the history.
  static const _catchUp = 3;

  Future<void> _syncReminders(List<PlannedPayment> planned) async {
    final accounts = ref.read(accountsProvider).value ?? const [];
    final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
    await ref
        .read(plannedRemindersProvider)
        .sync(
          planned,
          line: (p, before) {
            final amount = Money.format(
              p.amountMinor,
              Currencies.byCode(currencyOf[p.accountId] ?? 'PHP'),
            );
            final when = switch (before) {
              0 => 'today',
              1 => 'tomorrow',
              _ => 'in $before days',
            };
            return p.isIncome
                ? '${p.name} $amount is expected $when.'
                : '${p.name} $amount is due $when.';
          },
        );
  }

  Future<void> _autoLog(List<PlannedPayment> planned) async {
    _autoLogged = true;
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final actions = PlannedActions(
      ProviderScope.containerOf(context, listen: false),
    );
    final toast = Toast.of(context);
    final logged = <PlannedPaid>[];
    for (final original in planned.where((p) => p.autoLog && !p.isDone)) {
      var p = original;
      for (var i = 0; i < _catchUp && !p.nextDue.isAfter(today); i++) {
        try {
          final paid = await actions.pay(
            p,
            paidAt: p.nextDue == today
                ? now
                : DateTime(p.nextDue.year, p.nextDue.month, p.nextDue.day, 12),
          );
          logged.add(paid);
        } on Object {
          break; // Offline, say: it's tried again next time.
        }
        final next = p.nextAfter(p.nextDue);
        if (next == null) break;
        p = p.dueOn(next);
      }
    }
    if (logged.isEmpty || !mounted) return;
    toast.show(
      logged.length == 1
          ? 'Logged ${logged.single.planned.name} for you'
          : 'Logged ${logged.length} planned payments for you',
      icon: Icons.event_repeat_rounded,
      action: ToastAction('Undo', () async {
        for (final paid in logged.reversed) {
          await actions.undoPay(paid);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = switch (ref.watch(appLockProvider).value) {
      final s? => s.hasPin && !s.locked,
      null => false,
    };
    if (unlocked) {
      ref.listen(plannedProvider, (_, next) {
        if (next.value case final list?) _syncReminders(list);
      });
      final planned = ref.watch(plannedProvider).value;
      if (planned != null && !_autoLogged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _autoLogged) return;
          _syncReminders(planned);
          _autoLog(planned);
        });
      }
    }
    return widget.child;
  }
}
