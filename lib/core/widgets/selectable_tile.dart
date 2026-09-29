import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A tappable option that lights up in the theme colour when selected. Used
/// for currencies, account types and coaching tones, so every choice in
/// onboarding feels the same.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface.withValues(alpha: 0.55),
              border: Border.all(
                color: selected
                    ? AppColors.accentBright
                    : AppColors.hairline(0.07),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The round check shown on selected tiles.
class SelectionDot extends StatelessWidget {
  const SelectionDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accentBright : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accentBright : AppColors.textMuted,
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: AppColors.night)
          : null,
    );
  }
}
