import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/category.dart';
import '../category_style.dart';

/// Big category chips: an icon in a tinted circle, then the name. The
/// selected chip picks up its category color. A dashed "+ Add" chip sits at
/// the end.
///
/// When [collapsedCount] is set and [expanded] is false, only that many show;
/// "View all" in the section header reveals the rest.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
    this.expanded = true,
    this.collapsedCount = 8,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelected;
  final VoidCallback onCreate;
  final bool expanded;
  final int collapsedCount;

  @override
  Widget build(BuildContext context) {
    var shown = expanded
        ? categories
        : categories.take(collapsedCount).toList();
    // Never hide the selected category behind "View all".
    final selected = categories.where((c) => c.id == selectedId).firstOrNull;
    if (selected != null && !shown.contains(selected)) {
      shown = [...shown, selected];
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in shown)
          _CategoryChip(
            category: c,
            selected: c.id == selectedId,
            onTap: () => onSelected(c),
          ),
        _AddChip(onTap: onCreate),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.colorValue;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected
                ? color.withValues(alpha: 0.2)
                : AppColors.surface.withValues(alpha: 0.85),
            border: Border.all(
              color: selected ? color : AppColors.hairline(0.06),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: selected ? 0.3 : 0.16),
                ),
                child: Icon(category.iconData, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: text.titleMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'New category',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: CustomPaint(
          painter: const _DashedPill(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Add',
                  style: text.titleMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPill extends CustomPainter {
  const _DashedPill();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(22),
        ),
      );
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPill oldDelegate) => false;
}
