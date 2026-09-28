import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/round_icon_button.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.balancesHidden,
    required this.onToggleBalances,
    required this.now,
    required this.onOpenSettings,
  });

  final String name;
  final bool balancesHidden;
  final VoidCallback onToggleBalances;
  final DateTime now;
  final VoidCallback onOpenSettings;

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
              // One line, like a headline; a long name shrinks to fit
              // rather than wrapping.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${greeting(now)}, $name!',
                  maxLines: 1,
                  style: text.displaySmall?.copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
        ),
        RoundIconButton(
          icon: balancesHidden
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          semanticLabel: balancesHidden ? 'Show balances' : 'Hide balances',
          active: balancesHidden,
          onTap: onToggleBalances,
        ),
        const SizedBox(width: 10),
        RoundIconButton(
          icon: Icons.settings_rounded,
          semanticLabel: 'Settings',
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}
