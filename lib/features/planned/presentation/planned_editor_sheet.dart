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
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../application/planned_providers.dart';
import '../data/planned_reminders.dart';
import '../domain/planned_payment.dart';

/// Quick starts for the empty state: a name, an expense category icon and
/// how it repeats.
const plannedTemplates = <(String, String, PlannedRepeat)>[
  ('Rent', 'home', PlannedRepeat.monthly),
  ('Electricity', 'bills', PlannedRepeat.monthly),
  ('Internet', 'phone', PlannedRepeat.monthly),
  ('Netflix', 'fun', PlannedRepeat.monthly),
  ('Insurance', 'health', PlannedRepeat.yearly),
];

/// Adds a planned payment or edits one.
abstract final class PlannedEditorSheet {
  static Future<void> show(
    BuildContext context, {
    PlannedPayment? planned,
    (String, String, PlannedRepeat)? template,
    bool income = false,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _Editor(planned: planned, template: template, income: income),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({this.planned, this.template, this.income = false});

  final PlannedPayment? planned;
  final (String, String, PlannedRepeat)? template;
  final bool income;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  PlannedPayment? get _p => widget.planned;
  bool get _isEdit => _p != null;

  late TransactionKind _kind =
      _p?.kind ??
      (widget.income ? TransactionKind.income : TransactionKind.expense);
  late final _name = TextEditingController(
    text: _p?.name ?? widget.template?.$1 ?? (widget.income ? 'Salary' : ''),
  );
  late final _amount = TextEditingController();
  String? _accountId;
  String? _categoryId;
  late PlannedRepeat _repeat =
      _p?.repeat ?? widget.template?.$3 ?? PlannedRepeat.monthly;
  late int _every = _p?.every ?? 1;
  // A stopped one starting again picks up from tomorrow, not its old date.
  late DateTime _due = switch (_p) {
    final p? when !(p.isDone && p.nextDue.isBefore(_today)) => p.nextDue,
    _ => _today.add(const Duration(days: 1)),
  };
  late int? _remind = _isEdit ? _p!.remindDays : 1;
  late bool _auto = _p?.autoLog ?? false;
  bool _busy = false;
  bool _seeded = false;

  static DateTime get _today {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Fills in the account, category and amount once the lists are there.
  void _seed(List<Account> accounts, List<Category> categories) {
    if (_seeded || accounts.isEmpty) return;
    _seeded = true;
    final a =
        accounts.where((a) => a.id == _p?.accountId).firstOrNull ??
        accounts.first;
    _accountId = a.id;
    _categoryId =
        _p?.categoryId ??
        switch (widget.template?.$2) {
          final icon? =>
            categories
                .where(
                  (c) => c.icon == icon && c.kind == TransactionKind.expense,
                )
                .firstOrNull
                ?.id,
          null => null,
        };
    if (_p case final p?) {
      _amount.text = Money.toInputText(
        p.amountMinor,
        Currencies.byCode(a.currencyCode),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save(Currency currency) async {
    final amount = Money.parseMinor(_amount.text, currency);
    final accountId = _accountId;
    if (_busy || amount <= 0 || accountId == null) return;
    if (_name.text.trim().isEmpty) return;
    final toast = Toast.of(context);
    final actions = PlannedActions.of(context);
    final reminders = ref.read(plannedRemindersProvider);
    setState(() => _busy = true);
    final draft = PlannedDraft(
      kind: _kind,
      name: _name.text,
      amountMinor: amount,
      accountId: accountId,
      categoryId: _categoryId,
      repeat: _repeat,
      every: _repeat == PlannedRepeat.once ? 1 : _every,
      firstDue: _due,
      anchorDay: _isEdit && _p!.repeat == _repeat ? _p!.anchorDay : null,
      remindDays: _remind,
      autoLog: _repeat != PlannedRepeat.once && _auto,
    );
    try {
      if (_remind != null) await reminders.requestPermission();
      if (_isEdit) {
        await actions.update(_p!.id, draft);
      } else {
        await actions.create(draft);
      }
      HapticFeedback.selectionClick();
      toast.show(
        _isEdit ? 'Saved' : '${draft.name.trim()} planned',
        icon: Icons.event_repeat_rounded,
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
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    _seed(accounts, categories);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final currency = Currencies.byCode(account?.currencyCode ?? 'PHP');
    final kindCategories = categories
        .where((c) => c.kind == _kind && !c.hidden)
        .toList();
    final unit = switch (_repeat) {
      PlannedRepeat.weekly => _every == 1 ? 'week' : 'weeks',
      PlannedRepeat.monthly => _every == 1 ? 'month' : 'months',
      PlannedRepeat.yearly => _every == 1 ? 'year' : 'years',
      PlannedRepeat.once => '',
    };
    final income = _kind == TransactionKind.income;
    final valid =
        _name.text.trim().isNotEmpty &&
        Money.parseMinor(_amount.text, currency) > 0 &&
        account != null;

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
                _isEdit
                    ? 'Edit ${_p!.name}'
                    : income
                    ? 'Plan income'
                    : 'Plan a payment',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                income
                    ? 'Money that comes in on a schedule, like your salary.'
                    : 'A bill or subscription. Velora reminds you, and one tap '
                          'logs it.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              SegmentedButton<TransactionKind>(
                segments: const [
                  ButtonSegment(
                    value: TransactionKind.expense,
                    icon: Icon(Icons.north_east_rounded, size: 18),
                    label: Text('Bill'),
                  ),
                  ButtonSegment(
                    value: TransactionKind.income,
                    icon: Icon(Icons.south_west_rounded, size: 18),
                    label: Text('Income'),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 14),
              const FieldCaption('Name'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  hintText: income ? 'e.g. Salary' : 'e.g. Meralco',
                  prefixIcon: const Icon(Icons.event_repeat_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              MoneyField(
                controller: _amount,
                currency: currency,
                label: income ? 'Amount' : 'Usual amount',
                helper: income
                    ? null
                    : 'For bills that change, you can adjust it when you pay.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              FieldCaption(income ? 'Comes into' : 'Paid from'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    ChoiceChip(
                      label: Text(a.name),
                      selected: a.id == _accountId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    ),
                ],
              ),
              if (kindCategories.isNotEmpty) ...[
                const SizedBox(height: 14),
                const FieldCaption('Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kindCategories)
                      ChoiceChip(
                        avatar: Icon(c.iconData, size: 18, color: c.colorValue),
                        label: Text(c.name),
                        selected: c.id == _categoryId,
                        showCheckmark: false,
                        onSelected: (_) => setState(
                          () => _categoryId = c.id == _categoryId ? null : c.id,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              FieldCaption(_isEdit ? 'Next due' : 'First due'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, day) in [
                    ('Today', _today),
                    ('Tomorrow', _today.add(const Duration(days: 1))),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _due == day,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _due = day),
                    ),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: AppColors.leafBright,
                    ),
                    label: Text(
                      _due.difference(_today).inDays > 1 ||
                              _due.isBefore(_today)
                          ? DateFormat('EEE, MMM d, y').format(_due)
                          : 'Pick a date',
                    ),
                    selected:
                        _due.difference(_today).inDays > 1 ||
                        _due.isBefore(_today),
                    showCheckmark: false,
                    onSelected: (_) => _pickDate(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldCaption('Repeats'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in PlannedRepeat.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: r == _repeat,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _repeat = r),
                    ),
                ],
              ),
              if (_repeat != PlannedRepeat.once) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Every', style: text.bodyMedium),
                    IconButton(
                      tooltip: 'Less often',
                      onPressed: _every > 1
                          ? () => setState(() => _every--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text('$_every', style: text.titleMedium),
                    IconButton(
                      tooltip: 'More apart',
                      onPressed: _every < 12
                          ? () => setState(() => _every++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    Text(unit, style: text.bodyMedium),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const FieldCaption('Remind me'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, days) in const [
                    ('Off', null),
                    ('On the day', 0),
                    ('1 day before', 1),
                    ('3 days before', 3),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _remind == days,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _remind = days),
                    ),
                ],
              ),
              if (_repeat != PlannedRepeat.once) ...[
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                  title: Text(
                    'Log it for me on the day',
                    style: text.titleMedium?.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    'For fixed amounts, like subscriptions. You can undo.',
                    style: text.labelMedium,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : income
                    ? 'Plan income'
                    : 'Plan it',
                icon: Icons.event_repeat_rounded,
                onPressed: valid && !_busy ? () => _save(currency) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
