import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.balancesHidden,
    required this.onToggleBalances,
    required this.now,
  });

  final String name;
  final bool balancesHidden;
  final VoidCallback onToggleBalances;
  final DateTime now;

  static String greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Up late',
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
                style: text.labelMedium?.copyWith(letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                '${greeting(now)},\n$name!',
                style: text.displaySmall?.copyWith(fontSize: 30),
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: balancesHidden
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          semanticLabel: balancesHidden ? 'Show balances' : 'Hide balances',
          active: balancesHidden,
          onTap: onToggleBalances,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
                ? AppColors.leaf.withValues(alpha: 0.25)
                : AppColors.surface.withValues(alpha: 0.6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 22,
              color: active ? AppColors.leafBright : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
