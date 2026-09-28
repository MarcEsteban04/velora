import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_type_style.dart';
import '../../profile/data/profile_repository.dart';
import '../application/amount_expression.dart';
import '../application/transaction_providers.dart';
import '../domain/transaction.dart';
import 'category_style.dart';
import 'widgets/account_picker_sheet.dart';
import 'widgets/amount_display.dart';
import 'widgets/calc_keypad.dart';
import 'widgets/category_chips.dart';
import 'widgets/kind_switcher.dart';
import 'widgets/new_category_sheet.dart';

/// Log (or edit) an expense, income or transfer on one screen.
///
/// The amount is a live calculator. Category, date, time and account are
/// one tap each. The Save button says exactly what's missing, or exactly
/// what will be saved.
class TransactionEntryScreen extends ConsumerStatefulWidget {
  const TransactionEntryScreen({
    super.key,
    this.initialKind = TransactionKind.expense,
    this.existing,
  });

  final TransactionKind initialKind;
  final Transaction? existing;

  static Route<void> route({
    TransactionKind kind = TransactionKind.expense,
    Transaction? existing,
  }) => MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        TransactionEntryScreen(initialKind: kind, existing: existing),
  );

  @override
  ConsumerState<TransactionEntryScreen> createState() =>
      _TransactionEntryScreenState();
}

class _TransactionEntryScreenState
    extends ConsumerState<TransactionEntryScreen> {
  late TransactionKind _kind = widget.existing?.kind ?? widget.initialKind;
  AmountExpression _expr = const AmountExpression();

  /// Editing pre-fills the amount once the account (and so its currency's
  /// decimal places) is known.
  late bool _exprReady = widget.existing == null;
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  late String? _toAccountId = widget.existing?.toAccountId;
  late DateTime _when = widget.existing?.occurredAt ?? DateTime.now();
  late final _note = TextEditingController(text: widget.existing?.note);
  final _toAmount = TextEditingController();
  final _noteFocus = FocusNode();
  bool _saving = false;
  bool _amountAdjusted = false;

  bool get _isEdit => widget.existing != null;

  /// Minor units as plain calculator text: "150" or "150.5", never grouped.
  static String _plain(int minor, int digits) {
    final unit = math.pow(10, digits).toInt();
    final fraction = minor % unit;
    if (fraction == 0) return '${minor ~/ unit}';
    final f = fraction
        .toString()
        .padLeft(digits, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${minor ~/ unit}.$f';
  }

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _toAmount.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _setKind(TransactionKind k) => setState(() {
    _kind = k;
    _categoryId = null;
  });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(
      () => _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null) return;
    setState(
      () => _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _pickAccount(List<Account> accounts, {bool to = false}) async {
    final picked = await AccountPickerSheet.show(
      context,
      accounts: accounts,
      title: to
          ? 'Send to'
          : (_kind == TransactionKind.transfer ? 'Send from' : 'Account'),
      selectedId: to ? _toAccountId : _accountId,
      disabledId: _kind == TransactionKind.transfer
          ? (to ? _accountId : _toAccountId)
          : null,
    );
    if (picked == null) return;
    setState(() => to ? _toAccountId = picked.id : _accountId = picked.id);
  }

  String _dayLabel(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(d);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  Future<void> _save({
    required int amountMinor,
    required Currency currency,
    required int? toAmountMinor,
  }) async {
    setState(() => _saving = true);
    final draft = TransactionDraft(
      kind: _kind,
      amountMinor: amountMinor,
      accountId: _accountId!,
      toAccountId: _toAccountId,
      toAmountMinor: toAmountMinor,
      categoryId: _categoryId,
      note: _note.text,
      occurredAt: _when,
    );
    final actions = TransactionActions.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = _isEdit
          ? await actions.update(widget.existing!.id, draft)
          : await actions.create(draft);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? 'Changes saved'
                  : '${_kind.label} saved · ${Money.format(amountMinor, currency)}',
            ),
            action: _isEdit
                ? null
                : SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.leafBright,
                    onPressed: () => actions.delete(saved.id),
                  ),
          ),
        );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(error, action: 'save that'))),
      );
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Delete this transaction?'),
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
    if (ok != true || !mounted) return;
    final actions = TransactionActions.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await actions.delete(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.leafBright,
            onPressed: () => actions.create(existing.toDraft()),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(error, action: 'delete that'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider);
    final recent = ref.watch(recentTransactionsProvider).value;
    final mainCode = ref.watch(profileProvider).value?.currencyCode ?? 'USD';

    // Smart defaults: the account used most recently, else the first one.
    // A transfer goes to the next account along.
    if (_accountId == null && accounts.isNotEmpty) {
      final last = recent?.firstOrNull?.accountId;
      _accountId = accounts.any((a) => a.id == last) ? last : accounts.first.id;
    }
    if (_kind == TransactionKind.transfer &&
        _toAccountId == null &&
        accounts.length > 1) {
      _toAccountId = accounts.firstWhere((a) => a.id != _accountId).id;
    }

    Account? byId(String? id) =>
        id == null ? null : accounts.where((a) => a.id == id).firstOrNull;
    final account = byId(_accountId);
    final toAccount = byId(_toAccountId);
    final currency = Currencies.byCode(account?.currencyCode ?? mainCode);
    final toCurrency = Currencies.byCode(
      toAccount?.currencyCode ?? currency.code,
    );
    final crossCurrency =
        _kind == TransactionKind.transfer &&
        toAccount != null &&
        toCurrency != currency;
    if (!_exprReady && account != null) {
      _expr = AmountExpression(
        _plain(widget.existing!.amountMinor, currency.decimalDigits),
      );
      _exprReady = true;
    }
    final amount = _expr.evaluate(decimalDigits: currency.decimalDigits);
    final toAmount = crossCurrency
        ? Money.parseMinor(_toAmount.text, toCurrency)
        : null;
    if (_isEdit &&
        crossCurrency &&
        !_amountAdjusted &&
        _toAmount.text.isEmpty) {
      final existing = widget.existing!.toAmountMinor;
      if (existing != null) {
        _toAmount.text = Money.toInputText(existing, toCurrency);
      }
    }

    final String? blocker = switch (true) {
      _ when accounts.isEmpty => 'Add an account first',
      _ when amount == 0 => 'Enter an amount',
      _ when _kind != TransactionKind.transfer && _categoryId == null =>
        'Pick a category',
      _ when _kind == TransactionKind.transfer && accounts.length < 2 =>
        'You need two accounts to transfer',
      _ when _kind == TransactionKind.transfer && toAccount == null =>
        'Choose where it goes',
      _ when crossCurrency && (toAmount ?? 0) == 0 =>
        'Enter the amount received',
      _ => null,
    };
    final saveLabel =
        blocker ??
        (_isEdit
            ? 'Save changes'
            : 'Save ${_kind.label.toLowerCase()} · ${Money.format(amount, currency)}');
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.1,
            colors: [_kind.color.withValues(alpha: 0.2), AppColors.night],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: KindSwitcher(
                        value: _kind,
                        onChanged: _setKind,
                        enabled: !_isEdit,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _isEdit
                        ? IconButton(
                            tooltip: 'Delete',
                            onPressed: _delete,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.rust,
                            ),
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ),
              AmountDisplay(
                expression: _expr,
                currency: currency,
                color: _kind.color,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    TextField(
                      controller: _note,
                      focusNode: _noteFocus,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(140)],
                      textInputAction: TextInputAction.done,
                      style: text.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add a note (optional)',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    if (_kind == TransactionKind.transfer)
                      _TransferAccounts(
                        from: account,
                        to: toAccount,
                        onPickFrom: () => _pickAccount(accounts),
                        onPickTo: () => _pickAccount(accounts, to: true),
                        onSwap: toAccount == null
                            ? null
                            : () => setState(() {
                                final a = _accountId;
                                _accountId = _toAccountId;
                                _toAccountId = a;
                              }),
                      )
                    else ...[
                      const FieldLabel('Category'),
                      categories.when(
                        data: (all) => CategoryChips(
                          categories: all
                              .where((c) => c.kind == _kind)
                              .toList(),
                          selectedId: _categoryId,
                          onSelected: (c) => setState(() => _categoryId = c.id),
                          onCreate: () async {
                            final created = await NewCategorySheet.show(
                              context,
                              _kind,
                            );
                            if (created != null) {
                              setState(() => _categoryId = created.id);
                            }
                          },
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.leafBright,
                            ),
                          ),
                        ),
                        error: (e, _) => TextButton.icon(
                          onPressed: () => ref.invalidate(categoriesProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            friendlyError(e, action: 'load categories'),
                          ),
                        ),
                      ),
                    ],
                    if (crossCurrency) ...[
                      FieldLabel('${toAccount.name} receives'),
                      TextField(
                        controller: _toAmount,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: toCurrency.decimalDigits > 0,
                        ),
                        inputFormatters: [
                          MoneyInputFormatter(toCurrency.decimalDigits),
                        ],
                        style: text.titleMedium,
                        onChanged: (_) =>
                            setState(() => _amountAdjusted = true),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: '${toCurrency.symbol} ',
                          helperText: 'Different currencies. Enter what actually arrived.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailChip(
                          icon: Icons.calendar_today_rounded,
                          label: _dayLabel(_when),
                          onTap: _pickDate,
                        ),
                        _DetailChip(
                          icon: Icons.schedule_rounded,
                          label: DateFormat('h:mm a').format(_when),
                          onTap: _pickTime,
                        ),
                        if (_kind != TransactionKind.transfer &&
                            account != null)
                          _DetailChip(
                            icon: account.type.icon,
                            label: account.name,
                            onTap: () => _pickAccount(accounts),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: keyboardOpen || _noteFocus.hasFocus
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: CalcKeypad(
                          accent: _kind.color,
                          allowDecimal: currency.decimalDigits > 0,
                          onDigit: (d) => setState(
                            () => _expr = _expr.digit(
                              d,
                              decimalDigits: currency.decimalDigits,
                            ),
                          ),
                          onDecimal: () => setState(
                            () => _expr = _expr.decimalPoint(
                              decimalDigits: currency.decimalDigits,
                            ),
                          ),
                          onOperator: (o) =>
                              setState(() => _expr = _expr.operator(o)),
                          onBackspace: () =>
                              setState(() => _expr = _expr.backspace()),
                          onClear: () =>
                              setState(() => _expr = const AmountExpression()),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: PressableButton(
                  label: _saving ? 'Saving…' : saveLabel,
                  onPressed: blocker == null && !_saving
                      ? () => _save(
                          amountMinor: amount,
                          currency: currency,
                          toAmountMinor: toAmount,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.7),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.leafBright),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// From → To, with a swap button between the two account tiles.
class _TransferAccounts extends StatelessWidget {
  const _TransferAccounts({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
  });

  final Account? from;
  final Account? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              _AccountTile(caption: 'FROM', account: from, onTap: onPickFrom),
              const SizedBox(height: 8),
              _AccountTile(caption: 'TO', account: to, onTap: onPickTo),
            ],
          ),
          Positioned(
            right: 20,
            child: Semantics(
              button: true,
              label: 'Swap accounts',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onSwap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onSwap!();
                      },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceRaised,
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.sky,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.caption,
    required this.account,
    required this.onTap,
  });

  final String caption;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = account;

    return Material(
      color: AppColors.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: a == null
                      ? null
                      : LinearGradient(colors: a.type.gradient),
                  color: a == null ? AppColors.surfaceRaised : null,
                ),
                child: Icon(
                  a?.type.icon ?? Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      a?.name ?? 'Choose an account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                    if (a != null)
                      Text(
                        Money.format(
                          a.balanceMinor,
                          Currencies.byCode(a.currencyCode),
                        ),
                        style: text.labelMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}
