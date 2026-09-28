import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/category.dart';
import '../category_style.dart';

/// Wrapping category chips, where the selected one fills with its own color,
/// plus a dashed "New" chip at the end.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          _Chip(
            selected: c.id == selectedId,
            color: c.colorValue,
            semanticLabel: c.name,
            onTap: () => onSelected(c),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(c.iconData, size: 18, color: c.colorValue),
                const SizedBox(width: 6),
                Text(
                  c.name,
                  style: text.labelMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        _Chip(
          selected: false,
          dashed: true,
          color: AppColors.leafBright,
          semanticLabel: 'New category',
          onTap: onCreate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.leafBright,
              ),
              const SizedBox(width: 4),
              Text(
                'New',
                style: text.labelMedium?.copyWith(
                  fontSize: 14,
                  color: AppColors.leafBright,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.selected,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.dashed = false,
  });

  final bool selected;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final bool dashed;

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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? color.withValues(alpha: 0.22)
                : AppColors.surface.withValues(alpha: 0.6),
            border: Border.all(
              color: selected
                  ? color
                  : dashed
                  ? AppColors.leafBright.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.07),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
