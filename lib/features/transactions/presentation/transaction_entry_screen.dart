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
import '../../accounts/presentation/widgets/account_avatar.dart';
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

/// Log (or edit) an expense, income or transfer.
///
/// Layout, top to bottom:
/// - Expense | Income switch (transfers get their own title).
/// - Currency pill and a big live-calculated amount.
/// - Note, category chips (with "View all"), and the "Logged at" date and
///   time.
/// - A calculator panel floating over the form, which can be hidden.
/// - The account and Save side by side at the bottom.
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
  late bool _padOpen = widget.existing == null;
  bool _showAllCategories = false;
  bool _toAmountTouched = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isTransfer => _kind == TransactionKind.transfer;

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() {
      if (_noteFocus.hasFocus) setState(() => _padOpen = false);
    });
    // Anything that failed to load earlier (offline, or before a migration)
    // gets another go now, so the screen doesn't show a stale error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(categoriesProvider).hasError) {
        ref.invalidate(categoriesProvider);
      }
      if (ref.read(accountsProvider).hasError) ref.invalidate(accountsProvider);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _toAmount.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _openPad() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _padOpen = true);
  }

  void _edit(AmountExpression Function(AmountExpression e) change) =>
      setState(() => _expr = change(_expr));

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

  void _setDay(DateTime day) => setState(
    () => _when = DateTime(
      day.year,
      day.month,
      day.day,
      _when.hour,
      _when.minute,
    ),
  );

  Future<void> _pickAccount(List<Account> accounts, {bool to = false}) async {
    final picked = await AccountPickerSheet.show(
      context,
      accounts: accounts,
      title: to ? 'Send to' : (_isTransfer ? 'Send from' : 'Account'),
      selectedId: to ? _toAccountId : _accountId,
      disabledId: _isTransfer ? (to ? _accountId : _toAccountId) : null,
    );
    if (picked == null) return;
    setState(() => to ? _toAccountId = picked.id : _accountId = picked.id);
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

    // Smart defaults: the most recently used account, else the first one. A
    // transfer goes to the next account along.
    if (_accountId == null && accounts.isNotEmpty) {
      final last = recent?.firstOrNull?.accountId;
      _accountId = accounts.any((a) => a.id == last) ? last : accounts.first.id;
    }
    if (_isTransfer && _toAccountId == null && accounts.length > 1) {
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
        _isTransfer && toAccount != null && toCurrency != currency;

    if (!_exprReady && account != null) {
      _expr = AmountExpression(
        AmountExpression.plain(
          widget.existing!.amountMinor,
          currency.decimalDigits,
        ),
      );
      final existingTo = widget.existing!.toAmountMinor;
      if (crossCurrency && existingTo != null) {
        _toAmount.text = Money.toInputText(existingTo, toCurrency);
      }
      _exprReady = true;
    }

    final amount = _expr.evaluate(decimalDigits: currency.decimalDigits);
    final toAmount = crossCurrency
        ? Money.parseMinor(_toAmount.text, toCurrency)
        : null;

    final String? blocker = switch (true) {
      _ when accounts.isEmpty => 'Add an account first',
      _ when amount == 0 => 'Enter an amount',
      _ when !_isTransfer && _categoryId == null => 'Pick a category',
      _ when _isTransfer && accounts.length < 2 =>
        'You need two accounts to transfer',
      _ when _isTransfer && toAccount == null => 'Choose where it goes',
      _ when crossCurrency && (toAmount ?? 0) == 0 =>
        'Enter the amount received',
      _ => null,
    };
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showPad = _padOpen && !keyboardOpen;
    final kindCategories =
        categories.value?.where((c) => c.kind == _kind).toList() ?? const [];

    final form = <Widget>[
      if (!_isTransfer) ...[
        _AccountTile(
          caption: _kind == TransactionKind.expense
              ? 'PAID FROM'
              : 'RECEIVED IN',
          account: account,
          accent: _kind.color,
          onTap: () => _pickAccount(accounts),
          afterMinor: account == null || amount == 0
              ? null
              : _kind == TransactionKind.expense
              ? account.balanceMinor - amount
              : account.balanceMinor + amount,
        ),
        const SizedBox(height: 12),
      ],
      if (_isTransfer) ...[
        const FieldLabel('Accounts'),
        _TransferAccounts(
          from: account,
          to: toAccount,
          fromAfter: account == null || amount == 0
              ? null
              : account.balanceMinor - amount,
          toAfter: toAccount == null || amount == 0
              ? null
              : toAccount.balanceMinor + (toAmount ?? amount),
          onPickFrom: () => _pickAccount(accounts),
          onPickTo: () => _pickAccount(accounts, to: true),
          onSwap: toAccount == null
              ? null
              : () => setState(() {
                  final a = _accountId;
                  _accountId = _toAccountId;
                  _toAccountId = a;
                }),
        ),
        if (crossCurrency) ...[
          FieldLabel('${toAccount.name} receives'),
          TextField(
            controller: _toAmount,
            keyboardType: TextInputType.numberWithOptions(
              decimal: toCurrency.decimalDigits > 0,
            ),
            inputFormatters: [MoneyInputFormatter(toCurrency.decimalDigits)],
            style: text.titleMedium,
            onChanged: (_) => setState(() => _toAmountTouched = true),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '${toCurrency.symbol} ',
              helperText: _toAmountTouched
                  ? null
                  : 'Different currencies. Enter what actually arrived.',
            ),
          ),
        ],
      ] else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 0, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'CATEGORY',
                  style: text.labelMedium?.copyWith(
                    fontSize: 12,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (kindCategories.length > 8)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showAllCategories = !_showAllCategories;
                    if (_showAllCategories) _padOpen = false;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.leafBright,
                    visualDensity: VisualDensity.compact,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(
                    _showAllCategories
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(_showAllCategories ? 'Show less' : 'View all'),
                ),
            ],
          ),
        ),
        categories.when(
          data: (_) => CategoryChips(
            categories: kindCategories,
            selectedId: _categoryId,
            expanded: _showAllCategories,
            onSelected: (c) => setState(() => _categoryId = c.id),
            onCreate: () async {
              final created = await NewCategorySheet.show(context, _kind);
              if (created != null) setState(() => _categoryId = created.id);
            },
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.leafBright),
            ),
          ),
          error: (e, _) => TextButton.icon(
            onPressed: () => ref.invalidate(categoriesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(friendlyError(e, action: 'load categories')),
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _note,
        focusNode: _noteFocus,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(140)],
        textInputAction: TextInputAction.done,
        style: text.bodyLarge?.copyWith(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Add a note...',
          prefixIcon: Icon(Icons.sticky_note_2_rounded, size: 20),
        ),
      ),
      const SizedBox(height: 18),
      _LoggedAtCard(
        when: _when,
        onPickDate: _pickDate,
        onPickTime: _pickTime,
        onQuickDay: _setDay,
      ),
    ];

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
                    _CircleButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Center(
                        child: _isTransfer
                            ? Text('Transfer', style: text.headlineSmall)
                            : KindSwitcher(
                                value: _kind,
                                enabled: !_isEdit,
                                onChanged: (k) => setState(() {
                                  _kind = k;
                                  _categoryId = null;
                                  _showAllCategories = false;
                                }),
                              ),
                      ),
                    ),
                    _isEdit
                        ? _CircleButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete',
                            color: AppColors.rust,
                            onTap: _delete,
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AmountDisplay(
                  expression: _expr,
                  currency: currency,
                  color: _kind.color,
                  hint: blocker,
                  onAmountTap: _openPad,
                  onCurrencyTap: () => _pickAccount(accounts),
                ),
              ),
              Expanded(
                // Clip so the hidden calculator slides fully out of sight
                // instead of peeking under the bottom bar.
                child: ClipRect(
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          showPad ? 318 : 20,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: form,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: !showPad,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            offset: showPad
                                ? Offset.zero
                                : const Offset(0, 1.1),
                            child: CalcKeypad(
                              allowDecimal: currency.decimalDigits > 0,
                              onDigit: (d) => _edit(
                                (e) => e.digit(
                                  d,
                                  decimalDigits: currency.decimalDigits,
                                ),
                              ),
                              onDecimal: () => _edit(
                                (e) => e.decimalPoint(
                                  decimalDigits: currency.decimalDigits,
                                ),
                              ),
                              onOperator: (o) => _edit((e) => e.operator(o)),
                              onBackspace: () => _edit((e) => e.backspace()),
                              onClear: () =>
                                  _edit((_) => const AmountExpression()),
                              onPercent: () => _edit(
                                (e) => e.percent(
                                  decimalDigits: currency.decimalDigits,
                                ),
                              ),
                              onEquals: () => _edit(
                                (e) => e.resolve(
                                  decimalDigits: currency.decimalDigits,
                                ),
                              ),
                              onHide: () => setState(() => _padOpen = false),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: PressableButton(
                  label: _saving
                      ? 'Saving…'
                      : _isEdit
                      ? 'Save changes'
                      : blocker != null
                      ? 'Save ${_kind.label}'
                      : _isTransfer
                      ? 'Transfer ${Money.format(amount, currency)}'
                      : '${_kind == TransactionKind.expense ? 'Pay' : 'Add'} '
                            '${Money.format(amount, currency)} '
                            '${_kind == TransactionKind.expense ? 'from' : 'to'} '
                            '${account?.name ?? 'account'}',
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.8),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

/// "Logged at": date and time boxes, plus one-tap Today and Yesterday.
class _LoggedAtCard extends StatelessWidget {
  const _LoggedAtCard({
    required this.when,
    required this.onPickDate,
    required this.onPickTime,
    required this.onQuickDay,
  });

  final DateTime when;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<DateTime> onQuickDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateUtils.dateOnly(when);

    Widget box(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Material(
        color: AppColors.night.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget quick(String label, DateTime d) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: day == d,
        showCheckmark: false,
        onSelected: (_) => onQuickDay(d),
        labelStyle: text.labelMedium?.copyWith(
          color: day == d ? AppColors.night : AppColors.textSecondary,
        ),
        selectedColor: AppColors.leafBright,
        backgroundColor: AppColors.night.withValues(alpha: 0.6),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LOGGED AT',
                  style: text.labelMedium?.copyWith(
                    fontSize: 12,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              quick('Today', today),
              quick('Yesterday', yesterday),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              box(
                Icons.calendar_month_rounded,
                DateFormat('MMM d, y').format(when),
                onPickDate,
              ),
              const SizedBox(width: 10),
              box(
                Icons.schedule_rounded,
                DateFormat('h:mm a').format(when),
                onPickTime,
              ),
            ],
          ),
        ],
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
    this.fromAfter,
    this.toAfter,
  });

  final Account? from;
  final Account? to;
  final int? fromAfter;
  final int? toAfter;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            _AccountTile(
              caption: 'FROM',
              account: from,
              onTap: onPickFrom,
              afterMinor: fromAfter,
              accent: AppColors.sky,
              reserveTrailing: true,
            ),
            const SizedBox(height: 8),
            _AccountTile(
              caption: 'TO',
              account: to,
              onTap: onPickTo,
              afterMinor: toAfter,
              accent: AppColors.sky,
              reserveTrailing: true,
            ),
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
    );
  }
}

/// One account, clearly labelled with where the money goes: "PAID FROM",
/// "RECEIVED IN", "FROM" or "TO". It shows the current balance and, once
/// there's an amount, the balance after this transaction.
class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.caption,
    required this.account,
    required this.onTap,
    this.afterMinor,
    this.accent = AppColors.leafBright,
    this.reserveTrailing = false,
  });

  final String caption;
  final Account? account;
  final VoidCallback onTap;

  /// The balance once this transaction is saved; null hides the preview.
  final int? afterMinor;
  final Color accent;

  /// Leaves room on the right for the transfer swap button.
  final bool reserveTrailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = account;
    final currency = Currencies.byCode(a?.currencyCode ?? 'USD');
    final balance = a == null ? '' : Money.format(a.balanceMinor, currency);
    final after = afterMinor == null
        ? null
        : Money.format(afterMinor!, currency);

    return Semantics(
      button: true,
      label: [
        caption,
        a?.name ?? 'no account',
        if (a != null) 'balance $balance',
        if (after != null) 'after $after',
        'change',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AccountAvatar(account: a, size: 46),
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
                          color: accent,
                        ),
                      ),
                      Text(
                        a?.name ?? 'Choose an account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(fontSize: 16),
                      ),
                      if (a != null)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: balance),
                              if (after != null) ...[
                                const WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                TextSpan(
                                  text: after,
                                  style: TextStyle(
                                    color: afterMinor! < 0
                                        ? AppColors.rust
                                        : accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(fontSize: 13),
                        ),
                    ],
                  ),
                ),
                if (reserveTrailing)
                  const SizedBox(width: 48)
                else
                  const Icon(
                    Icons.unfold_more_rounded,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
