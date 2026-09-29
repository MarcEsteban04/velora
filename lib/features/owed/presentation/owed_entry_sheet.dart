import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../application/owed_providers.dart';
import '../domain/owed.dart';
import 'owed_account_choice.dart';

enum OwedEntryMode { paidBack, lentMore }

/// They paid some back (maybe into an account), or the user lent them
/// more (maybe out of one).
abstract final class OwedEntrySheet {
  static Future<void> show(
    BuildContext context, {
    required OwedProgress progress,
    required OwedEntryMode mode,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OwedEntrySheet(progress: progress, mode: mode),
  );
}

class _OwedEntrySheet extends ConsumerStatefulWidget {
  const _OwedEntrySheet({required this.progress, required this.mode});

  final OwedProgress progress;
  final OwedEntryMode mode;

  @override
  ConsumerState<_OwedEntrySheet> createState() => _OwedEntrySheetState();
}

class _OwedEntrySheetState extends ConsumerState<_OwedEntrySheet> {
  static const _lastIntoKey = 'owed.lastPaidInto';

  Owed get _owed => widget.progress.owed;
  bool get _back => widget.mode == OwedEntryMode.paidBack;
  late final Currency _currency = Currencies.byCode(_owed.currencyCode);

  /// Paid back defaults to all of it.
  late final _amount = TextEditingController(
    text: _back && widget.progress.remainingMinor > 0
        ? Money.toInputText(widget.progress.remainingMinor, _currency)
        : '',
  );
  final _note = TextEditingController();
  late DateTime _day = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();

  /// Where repayments usually land is remembered; lending starts at none.
  late String? _accountId = _back
      ? ref.read(sharedPreferencesProvider).getString(_lastIntoKey)
      : null;
  bool _busy = false;

  int get _amountMinor => Money.parseMinor(_amount.text, _currency);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> accounts) async {
    final amount = _amountMinor;
    if (amount <= 0 || _busy) return;
    final toast = Toast.of(context);
    final actions = OwedActions.of(context);
    final prefs = ref.read(sharedPreferencesProvider);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final settled = _back && amount >= widget.progress.remainingMinor;
    setState(() => _busy = true);
    try {
      final entry = _back
          ? await actions.paidBack(
              _owed,
              amountMinor: amount,
              at: atNow(_day),
              accountId: account?.id,
            )
          : await actions.lentMore(
              _owed,
              amountMinor: amount,
              at: atNow(_day),
              accountId: account?.id,
              note: _note.text,
            );
      if (_back && account != null) {
        await prefs.setString(_lastIntoKey, account.id);
      }
      HapticFeedback.mediumImpact();
      toast.show(
        settled
            ? '${_owed.name} paid you back in full'
            : _back
            ? '${Money.format(amount, _currency)} back from ${_owed.name}'
            : '${Money.format(amount, _currency)} more lent to ${_owed.name}',
        icon: settled ? Icons.celebration_rounded : Icons.handshake_rounded,
        action: ToastAction('Undo', () => actions.undo(entry)),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'save that'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = widget.progress.remainingMinor;
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => a.currencyCode == _owed.currencyCode)
        .toList();
    if (_accountId != null && accounts.every((a) => a.id != _accountId)) {
      _accountId = null;
    }
    final amount = _amountMinor;
    final tooMuch = _back && amount > remaining;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _back ? '${_owed.name} paid back' : 'Lent ${_owed.name} more',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${Money.format(remaining, _currency)} still owed to you',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                currency: _currency,
                label: _back ? 'How much came back' : 'How much more',
                helper: tooMuch
                    ? 'That’s more than they owe. It will count as settled.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              if (_back && remaining > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: Text(
                        'All of it ${Money.short(remaining, _currency)}',
                      ),
                      onPressed: () => setState(
                        () => _amount.text = Money.toInputText(
                          remaining,
                          _currency,
                        ),
                      ),
                    ),
                    if (remaining >= 200)
                      ActionChip(
                        label: Text(
                          'Half ${Money.short(remaining ~/ 2, _currency)}',
                        ),
                        onPressed: () => setState(
                          () => _amount.text = Money.toInputText(
                            remaining ~/ 2,
                            _currency,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (!_back) ...[
                const SizedBox(height: 14),
                const FieldCaption('What for (optional)'),
                TextField(
                  controller: _note,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  style: text.titleMedium?.copyWith(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Grab home',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              OwedAccountChoice(
                label: _back ? 'Paid into' : 'Lent from',
                accounts: accounts,
                selectedId: _accountId,
                lending: !_back,
                onChanged: (id) => setState(() => _accountId = id),
              ),
              const SizedBox(height: 14),
              DayChoice(
                label: _back ? 'Paid back' : 'Lent',
                value: _day,
                onChanged: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _back
                    ? 'Got ${Money.format(amount, _currency)}'
                    : 'Lend ${Money.format(amount, _currency)}',
                icon: _back
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_rounded,
                onPressed: amount > 0 && !_busy ? () => _save(accounts) : null,
              ),
              if (_back && remaining == 0) ...[
                const SizedBox(height: 10),
                Text(
                  'This one is already settled.',
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.leafBright,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
