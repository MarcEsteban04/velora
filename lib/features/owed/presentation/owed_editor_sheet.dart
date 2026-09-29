import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../application/owed_providers.dart';
import '../domain/owed.dart';
import 'owed_account_choice.dart';

/// Adds someone who owes the user, with what was lent (and maybe the
/// account it came out of), or edits who, what for and when it's due back.
abstract final class OwedEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required Currency currency,
    Owed? owed,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OwedEditor(currency: currency, owed: owed),
  );
}

class _OwedEditor extends ConsumerStatefulWidget {
  const _OwedEditor({required this.currency, this.owed});

  final Currency currency;
  final Owed? owed;

  @override
  ConsumerState<_OwedEditor> createState() => _OwedEditorState();
}

class _OwedEditorState extends ConsumerState<_OwedEditor> {
  late Currency _currency = widget.owed == null
      ? widget.currency
      : Currencies.byCode(widget.owed!.currencyCode);
  late final _name = TextEditingController(text: widget.owed?.name ?? '');
  late final _note = TextEditingController(text: widget.owed?.note ?? '');
  final _amount = TextEditingController();
  late DateTime? _dueOn = widget.owed?.dueOn;
  late DateTime _lentOn = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();

  /// The account it was lent from; null means no account changes.
  String? _fromId;
  bool _busy = false;

  bool get _isEdit => widget.owed != null;
  int get _amountMinor => Money.parseMinor(_amount.text, _currency);
  bool get _valid =>
      _name.text.trim().isNotEmpty && (_isEdit || _amountMinor > 0);

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? today.add(const Duration(days: 7)),
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    final toast = Toast.of(context);
    final actions = OwedActions.of(context);
    setState(() => _busy = true);
    final draft = OwedDraft(
      name: _name.text,
      note: _note.text,
      currencyCode: _currency.code,
      dueOn: _dueOn,
    );
    try {
      if (widget.owed case final o?) {
        await actions.update(o.id, draft);
        toast.show('Saved', icon: Icons.handshake_rounded);
      } else {
        await actions.create(
          draft,
          lentMinor: _amountMinor,
          lentAt: atNow(_lentOn),
          accountId: _fromId,
        );
        toast.show(
          '${draft.name.trim()} owes you '
          '${Money.format(_amountMinor, _currency)}',
          icon: Icons.handshake_rounded,
        );
      }
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'save that'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => a.currencyCode == _currency.code)
        .toList();
    if (_fromId != null && accounts.every((a) => a.id != _fromId)) {
      _fromId = null;
    }

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
                _isEdit ? 'Edit' : 'Someone owes you',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _isEdit
                    ? 'What you lent and what came back are in the history.'
                    : 'Velora keeps count until it’s all paid back.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              const FieldCaption('Who'),
              TextField(
                controller: _name,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(32)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'e.g. Juan',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 14),
                MoneyField(
                  controller: _amount,
                  currency: _currency,
                  label: 'How much you lent',
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await CurrencyPickerSheet.show(
                        context,
                        _currency,
                      );
                      if (picked == null || picked == _currency) return;
                      setState(() {
                        final amount = Money.parseMinor(_amount.text, picked);
                        _currency = picked;
                        _amount.text = amount == 0
                            ? ''
                            : Money.toInputText(amount, picked);
                      });
                    },
                    icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                    label: Text('In ${_currency.code}'),
                  ),
                ),
              ] else
                const SizedBox(height: 14),
              const FieldCaption('What for (optional)'),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'e.g. Concert tickets',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const FieldCaption('Pay back by (optional)'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: AppColors.accentBright,
                    ),
                    label: Text(
                      _dueOn == null
                          ? 'Pick a date'
                          : DateFormat('d MMM y').format(_dueOn!),
                    ),
                    onPressed: _pickDue,
                  ),
                  if (_dueOn != null)
                    ActionChip(
                      label: const Text('No date'),
                      onPressed: () => setState(() => _dueOn = null),
                    ),
                ],
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 14),
                OwedAccountChoice(
                  label: 'Lent from',
                  accounts: accounts,
                  selectedId: _fromId,
                  lending: true,
                  onChanged: (id) => setState(() => _fromId = id),
                ),
                const SizedBox(height: 14),
                DayChoice(
                  label: 'Lent',
                  value: _lentOn,
                  onChanged: (d) => setState(() => _lentOn = d),
                ),
              ],
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : 'Add ${Money.format(_amountMinor, _currency)}',
                icon: Icons.handshake_rounded,
                onPressed: _valid && !_busy ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
