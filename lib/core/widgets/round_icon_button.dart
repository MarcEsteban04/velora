import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A 48pt circular icon button for headers. [active] tints it green.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.surface.withValues(alpha: 0.6),
            border: Border.all(color: AppColors.hairline(0.08)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 22,
              color: active ? AppColors.accentBright : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
