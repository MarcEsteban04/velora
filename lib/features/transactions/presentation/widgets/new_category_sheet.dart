import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/pressable_button.dart';
import '../../application/transaction_providers.dart';
import '../../data/transaction_repository.dart';
import '../../domain/category.dart';
import '../../domain/transaction.dart';
import '../category_style.dart';

/// Create a custom category: a name, an icon and a color, with a live
/// preview chip. It returns the new category.
class NewCategorySheet extends ConsumerStatefulWidget {
  const NewCategorySheet({super.key, required this.kind});

  final TransactionKind kind;

  static Future<Category?> show(BuildContext context, TransactionKind kind) =>
      showModalBottomSheet<Category>(
        context: context,
        isScrollControlled: true,
        builder: (_) => NewCategorySheet(kind: kind),
      );

  @override
  ConsumerState<NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends ConsumerState<NewCategorySheet> {
  final _name = TextEditingController();
  String _icon = 'coffee';
  String _color = 'ember';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(categoryRepositoryProvider)
          .create(
            CategoryDraft(
              kind: widget.kind,
              name: _name.text,
              icon: _icon,
              color: _color,
            ),
          );
      ref.invalidate(categoriesProvider);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, created);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(error, action: 'create the category')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = CategoryStyle.colorOf(_color);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New ${widget.kind.label.toLowerCase()} category',
                style: text.headlineSmall,
              ),
              const FieldLabel('Name'),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                style: text.titleMedium,
                decoration: InputDecoration(
                  hintText: 'e.g. Coffee',
                  prefixIcon: Icon(CategoryStyle.iconOf(_icon), color: color),
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
              const SizedBox(height: 24),
              PressableButton(
                label: _saving ? 'Creating…' : 'Create category',
                onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
              ),
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
              color: selected ? ring : Colors.white.withValues(alpha: 0.06),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
