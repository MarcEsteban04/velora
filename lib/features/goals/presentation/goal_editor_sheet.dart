import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_button.dart';
import '../application/goal_providers.dart';
import '../domain/goal.dart';
import 'goal_style.dart';
import '../../../core/widgets/island_toast.dart';

/// Creates or edits a goal: name, target, optional date, icon and color.
/// It saves on its own and closes when done.
abstract final class GoalEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required Currency currency,
    Goal? existing,
    ({String name, String icon, String color})? template,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Editor(
      currency: existing?.currency ?? currency,
      existing: existing,
      template: template,
      actions: GoalActions.of(context),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.currency,
    required this.existing,
    required this.template,
    required this.actions,
  });

  final Currency currency;
  final Goal? existing;
  final ({String name, String icon, String color})? template;
  final GoalActions actions;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.template?.name ?? '',
  );
  late final _target = TextEditingController(
    text: Money.toInputText(widget.existing?.targetMinor ?? 0, widget.currency),
  );
  late String _icon =
      widget.existing?.icon ?? widget.template?.icon ?? 'savings';
  late String _color =
      widget.existing?.color ?? widget.template?.color ?? 'leaf';
  late DateTime? _date = widget.existing?.targetDate;
  bool _busy = false;

  int get _targetMinor => Money.parseMinor(_target.text, widget.currency);
  bool get _valid => _name.text.trim().isNotEmpty && _targetMinor > 0;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year + 30),
      helpText: 'Reach it by',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _run(Future<void> Function() job, String action) async {
    setState(() => _busy = true);
    final toast = Toast.of(context);
    final nav = Navigator.of(context);
    try {
      await job();
      HapticFeedback.selectionClick();
      nav.pop();
    } on Object catch (error) {
      if (mounted) setState(() => _busy = false);
      toast.show(friendlyError(error, action: action), tone: ToastTone.error);
    }
  }

  Future<void> _confirmDelete(Goal g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Delete “${g.name}”?'),
        content: const Text(
          'Its progress and history go with it. Your accounts aren’t '
          'touched.',
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
    if (ok == true && mounted) {
      await _run(() => widget.actions.delete(g.id), 'delete the goal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = GoalStyle.colorOf(_color);
    final draft = GoalDraft(
      name: _name.text,
      targetMinor: _targetMinor,
      currencyCode: widget.currency.code,
      icon: _icon,
      color: _color,
      targetDate: _date,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New goal' : 'Edit goal',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(GoalStyle.iconOf(_icon), color: tint, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      autofocus:
                          widget.existing == null && widget.template == null,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(32)],
                      style: text.titleMedium,
                      decoration: const InputDecoration(
                        labelText: 'What are you saving for?',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _target,
                autofocus: widget.template != null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  MoneyInputFormatter(widget.currency.decimalDigits),
                ],
                style: text.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Target',
                  prefixText: '${widget.currency.symbol} ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Material(
                color: AppColors.surface.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.hairline(0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: _pickDate,
                  leading: Icon(Icons.event_rounded, color: AppColors.sky),
                  title: Text(
                    _date == null
                        ? 'Add a target date'
                        : 'By ${DateFormat('MMMM d, y').format(_date!)}',
                    style: text.titleMedium?.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Optional. Velora works out the monthly amount.',
                    style: text.labelMedium,
                  ),
                  trailing: _date == null
                      ? null
                      : IconButton(
                          tooltip: 'Remove date',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _date = null),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final MapEntry(:key, :value) in GoalStyle.icons.entries)
                    _Choice(
                      selected: key == _icon,
                      tint: tint,
                      semanticLabel: '$key icon',
                      onTap: () => setState(() => _icon = key),
                      child: Icon(
                        value,
                        size: 20,
                        color: key == _icon ? tint : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final key in GoalStyle.colorKeys)
                    Semantics(
                      button: true,
                      selected: key == _color,
                      label: '$key color',
                      child: GestureDetector(
                        onTap: () => setState(() => _color = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GoalStyle.colorOf(key),
                            border: Border.all(
                              color: key == _color
                                  ? AppColors.textPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: widget.existing == null ? 'Create goal' : 'Save',
                onPressed: _busy || !_valid
                    ? null
                    : () => _run(
                        () => switch (widget.existing) {
                          final g? => widget.actions.update(g.id, draft),
                          null => widget.actions.create(draft),
                        },
                        'save the goal',
                      ),
              ),
              if (widget.existing case final g?) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _busy ? null : () => _confirmDelete(g),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete goal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.tint,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color tint;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? tint : AppColors.hairline(0.08)),
        ),
        child: Center(child: child),
      ),
    ),
  );
}
