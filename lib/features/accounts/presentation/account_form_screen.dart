import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import 'account_type_style.dart';
import 'widgets/account_card.dart';
import 'institutions.dart';
import 'widgets/account_type_picker.dart';
import 'widgets/institution_picker.dart';
import '../../../core/widgets/island_toast.dart';

/// Add or edit an account. The card at the top previews exactly how the
/// account will look while the user fills in the form.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, required this.defaultCurrency})
    : account = null;

  const AccountFormScreen.edit({
    super.key,
    required Account this.account,
    required this.defaultCurrency,
  });

  final Account? account;
  final Currency defaultCurrency;

  static Route<void> route({
    required Currency defaultCurrency,
    Account? account,
  }) => MaterialPageRoute(
    builder: (_) => account == null
        ? AccountFormScreen(defaultCurrency: defaultCurrency)
        : AccountFormScreen.edit(
            account: account,
            defaultCurrency: defaultCurrency,
          ),
  );

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  late AccountType _type = widget.account?.type ?? AccountType.bank;
  late Currency _currency = widget.account == null
      ? widget.defaultCurrency
      : Currencies.byCode(widget.account!.currencyCode);
  late bool _include = widget.account?.includeInNetWorth ?? true;

  /// The user chose a currency themselves, so an institution won't change it.
  bool _currencyPicked = false;

  /// Chosen bank or e-wallet. Existing accounts start with the one saved,
  /// or the one recognised from their name.
  late Institution? _institution = widget.account == null
      ? null
      : Institutions.forAccount(widget.account!);

  /// Only a choice the user actually made gets saved; a name match keeps
  /// working on its own.
  bool _institutionPicked = false;

  void _pickInstitution(Institution? i) {
    final previous = _institution;
    setState(() {
      _institution = i;
      _institutionPicked = true;
      if (i != null) _type = i.type;
      // A new Payoneer account holds dollars, unless told otherwise.
      final code = i?.currencyCode;
      if (code != null && !_isEdit && !_currencyPicked) {
        final minor = Money.parseMinor(_balance.text, _currency);
        _currency = Currencies.byCode(code);
        _balance.text = minor == 0 ? '' : Money.toInputText(minor, _currency);
      }
      // Fill in the name, unless the user typed their own.
      final current = _name.text.trim();
      final untouched =
          current.isEmpty ||
          current == previous?.name ||
          AccountType.values.any((t) => t.defaultName == current);
      if (i != null && untouched) _name.text = i.name;
    });
  }

  void _setType(AccountType t) => setState(() {
    _type = t;
    if (_institution != null && _institution!.type != t) {
      _institution = null;
      _institutionPicked = true;
    }
  });
  late final _name = TextEditingController(text: widget.account?.name ?? '');

  /// For credit, what was owed when it was added, typed as a positive
  /// number.
  late final _balance = TextEditingController(
    text: switch (widget.account) {
      null => '',
      final a when a.isCredit => Money.toInputText(
        -a.openingBalanceMinor,
        _currency,
      ),
      final a => Money.toInputText(a.openingBalanceMinor, _currency),
    },
  );
  late final _limit = TextEditingController(
    text: switch (widget.account?.creditLimitMinor) {
      final l? => Money.toInputText(l, _currency),
      null => '',
    },
  );
  bool _saving = false;

  bool get _isEdit => widget.account != null;
  bool get _credit => _type == AccountType.credit;

  /// The opening balance as stored: what's owed on credit is below zero.
  int get _balanceMinor {
    final typed = Money.parseMinor(_balance.text, _currency);
    return _credit ? -typed : typed;
  }

  int? get _limitMinor => switch (Money.parseMinor(_limit.text, _currency)) {
    final l when l > 0 && _credit => l,
    _ => null,
  };
  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final picked = await CurrencyPickerSheet.show(context, _currency);
    if (picked == null || picked == _currency) return;
    // Keep the amount the user typed, re-read with the new currency's
    // decimal rules.
    final minor = Money.parseMinor(_balance.text, picked);
    final limit = Money.parseMinor(_limit.text, picked);
    setState(() {
      _currency = picked;
      _currencyPicked = true;
      _balance.text = Money.toInputText(minor, picked);
      _limit.text = limit == 0 ? '' : Money.toInputText(limit, picked);
    });
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final draft = AccountDraft(
      name: _name.text,
      type: _type,
      currencyCode: _currency.code,
      openingBalanceMinor: _balanceMinor,
      includeInNetWorth: _include,
      institutionId: _institutionPicked ? _institution?.id : null,
      creditLimitMinor: _limitMinor,
    );
    final repo = ref.read(accountRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(widget.account!.id, draft);
      } else {
        await repo.create(draft);
      }
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      Toast.of(context).show(
        friendlyError(error, action: 'save the account'),
        tone: ToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DuskBackdrop(showMoon: false)),
          Positioned.fill(
            child: ColoredBox(color: AppColors.night.withValues(alpha: 0.7)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEdit ? 'Edit account' : 'Add account',
                        style: text.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      FadeSlideIn(
                        scaleFrom: 0.95,
                        child: AccountCard(
                          name: _name.text.trim(),
                          type: _type,
                          currency: _currency,
                          balanceMinor: _balanceMinor,
                          // A picked brand wins; otherwise recognise the name
                          // as it's typed.
                          institution: _institutionPicked
                              ? _institution
                              : _institution ?? Institutions.match(_name.text),
                          creditLimitMinor: _limitMinor,
                        ),
                      ),
                      const FieldLabel('Account type'),
                      AccountTypePicker(selected: _type, onChanged: _setType),
                      if (Institutions.ofType(_type).isNotEmpty) ...[
                        FieldLabel(switch (_type) {
                          AccountType.bank => 'Bank',
                          AccountType.credit => 'Card or pay later',
                          _ => 'E-wallet',
                        }),
                        InstitutionPicker(
                          type: _type,
                          selected: _institution,
                          onChanged: _pickInstitution,
                        ),
                        if (Institutions.ofType(
                          _type,
                          international: true,
                        ).isNotEmpty) ...[
                          const FieldLabel('International bank'),
                          InstitutionPicker(
                            type: _type,
                            international: true,
                            selected: _institution,
                            onChanged: _pickInstitution,
                          ),
                        ],
                      ],
                      const FieldLabel('Account name'),
                      TextField(
                        controller: _name,
                        autofocus: !_isEdit,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        style: text.titleMedium,
                        decoration: InputDecoration(
                          hintText: switch (_type) {
                            AccountType.cash => 'e.g. Wallet cash',
                            AccountType.bank => 'e.g. BPI Savings',
                            AccountType.eWallet => 'e.g. GCash',
                            AccountType.savings => 'e.g. Emergency fund',
                            AccountType.credit => 'e.g. BillEase',
                          },
                          prefixIcon: Icon(_type.icon, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const FieldLabel('Currency'),
                      _TappableField(
                        onTap: _pickCurrency,
                        leading: Text(
                          _currency.symbol,
                          style: text.titleMedium?.copyWith(
                            color: AppColors.accentBright,
                          ),
                        ),
                        title: '${_currency.code} · ${_currency.name}',
                      ),
                      FieldLabel(_credit ? 'Owed now' : 'Starting balance'),
                      TextField(
                        controller: _balance,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: _currency.decimalDigits > 0,
                        ),
                        inputFormatters: [
                          MoneyInputFormatter(_currency.decimalDigits),
                        ],
                        style: text.titleMedium?.copyWith(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 18, right: 10),
                            child: Text(
                              _currency.symbol,
                              style: text.titleMedium?.copyWith(
                                color: AppColors.accentBright,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_credit) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 6, top: 6),
                          child: Text(
                            'What you owe on it today. Spending on it adds '
                            'to this; paying the bill (a transfer in) brings '
                            'it down.',
                            style: text.labelMedium,
                          ),
                        ),
                        const FieldLabel('Credit limit (optional)'),
                        TextField(
                          controller: _limit,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: _currency.decimalDigits > 0,
                          ),
                          inputFormatters: [
                            MoneyInputFormatter(_currency.decimalDigits),
                          ],
                          style: text.titleMedium?.copyWith(fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'e.g. 17,500',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                left: 18,
                                right: 10,
                              ),
                              child: Text(
                                _currency.symbol,
                                style: text.titleMedium?.copyWith(
                                  color: AppColors.accentBright,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                        radius: 22,
                        // Own Material, so the switch ripple shows above the glass.
                        child: Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _include,
                            activeTrackColor: AppColors.accent,
                            onChanged: (v) => setState(() => _include = v),
                            title: Text(
                              'Include in net worth',
                              style: text.titleMedium?.copyWith(fontSize: 14),
                            ),
                            subtitle: Text(
                              'Turn off for money that isn’t really yours, like '
                              'a shared household wallet.',
                              style: text.labelMedium,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: PressableButton(
                    label: _saving
                        ? 'Saving…'
                        : _isEdit
                        ? 'Save changes'
                        : 'Add account',
                    onPressed: _valid && !_saving ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.onTap,
    required this.leading,
    required this.title,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.night.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.hairline(0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              SizedBox(width: 28, child: leading),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
