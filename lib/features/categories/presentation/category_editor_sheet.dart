import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/category_style.dart';
import '../application/category_actions.dart';
import '../../../core/widgets/island_toast.dart';

/// Creates a category, or edits one: name, icon and color, plus hide and
/// delete for existing ones. Returns the saved category, or null.
abstract final class CategoryEditorSheet {
  static Future<Category?> show(
    BuildContext context, {
    required TransactionKind kind,
    Category? existing,
    Widget? extra,
  }) => showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Editor(
      kind: existing?.kind ?? kind,
      existing: existing,
      extra: extra,
      actions: CategoryActions.of(context),
    ),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({
    required this.kind,
    required this.existing,
    required this.extra,
    required this.actions,
  });

  final TransactionKind kind;
  final Category? existing;

  /// Shown above the actions, for example the category's budget.
  final Widget? extra;
  final CategoryActions actions;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? 'coffee';
  late String _color = widget.existing?.color ?? 'ember';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _taken => isCategoryNameTaken(
    _name.text,
    ref.read(categoriesProvider).value ?? const [],
    except: widget.existing,
    kind: widget.kind,
  );

  void _toast(String message) =>
      Toast.of(context).show(message, tone: ToastTone.error);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _busy || _taken) return;
    setState(() => _busy = true);
    final draft = CategoryDraft(
      kind: widget.kind,
      name: _name.text,
      icon: _icon,
      color: _color,
    );
    try {
      final saved = switch (widget.existing) {
        final c? => await widget.actions.update(c.id, draft),
        null => await widget.actions.create(draft),
      };
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, saved);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        friendlyError(
          error,
          action: widget.existing == null
              ? 'create the category'
              : 'save the category',
        ),
      );
    }
  }

  Future<void> _toggleHidden(Category c) async {
    setState(() => _busy = true);
    try {
      await widget.actions.setHidden(c.id, !c.hidden);
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyError(error, action: 'update the category'));
    }
  }

  /// Deletes only unused categories, so no transaction quietly loses its
  /// category. Used ones are offered hiding instead.
  Future<void> _delete(Category c) async {
    setState(() => _busy = true);
    try {
      final used = await widget.actions.usage(c.id);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: Text(
            used == 0 ? 'Delete “${c.name}”?' : '“${c.name}” is in use',
          ),
          content: Text(
            used == 0
                ? 'It isn’t used by any transaction, so nothing else changes.'
                : '$used ${used == 1 ? 'transaction uses' : 'transactions use'} '
                      'it. Hide it instead: it leaves the pickers, and your '
                      'history keeps it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: used == 0
                    ? AppColors.rust
                    : AppColors.leafBright,
              ),
              child: Text(used == 0 ? 'Delete' : 'Hide it'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (used == 0) {
        await widget.actions.delete(c.id);
      } else {
        await widget.actions.setHidden(c.id, true);
      }
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(friendlyError(error, action: 'delete the category'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = CategoryStyle.colorOf(_color);
    final existing = widget.existing;
    final taken = _name.text.trim().isNotEmpty && _taken;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      existing == null
                          ? 'New ${widget.kind.label.toLowerCase()} category'
                          : 'Edit category',
                      style: text.headlineSmall,
                    ),
                  ),
                  if (existing == null)
                    const VeloraMascot(
                      pose: MascotPose.categories,
                      size: 64,
                      halo: false,
                    ),
                ],
              ),
              const FieldLabel('Name'),
              TextField(
                controller: _name,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                style: text.titleMedium,
                decoration: InputDecoration(
                  hintText: 'e.g. Coffee',
                  prefixIcon: Icon(CategoryStyle.iconOf(_icon), color: color),
                  errorText: taken
                      ? 'You already have a category called that'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const FieldLabel('Icon'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in CategoryStyle.icons.entries)
                    _Swatch(
                      selected: e.key == _icon,
                      ring: color,
                      semanticLabel: '${e.key} icon',
                      onTap: () => setState(() => _icon = e.key),
                      child: Icon(
                        e.value,
                        size: 20,
                        color: e.key == _icon ? color : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const FieldLabel('Color'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in CategoryStyle.colors.entries)
                    _Swatch(
                      selected: e.key == _color,
                      ring: e.value,
                      semanticLabel: '${e.key} color',
                      onTap: () => setState(() => _color = e.key),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.value,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.extra != null) ...[
                const SizedBox(height: 18),
                widget.extra!,
              ],
              const SizedBox(height: 22),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : existing == null
                    ? 'Create category'
                    : 'Save',
                onPressed: _name.text.trim().isEmpty || _busy || taken
                    ? null
                    : _save,
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _toggleHidden(existing),
                        icon: Icon(
                          existing.hidden
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        label: Text(existing.hidden ? 'Show again' : 'Hide'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _delete(existing),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.rust,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.selected,
    required this.ring,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color ring;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? ring.withValues(alpha: 0.18)
                : AppColors.surfaceRaised.withValues(alpha: 0.8),
            border: Border.all(
              color: selected ? ring : AppColors.hairline(0.06),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
