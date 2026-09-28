import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/account.dart';
import '../institutions.dart';
import 'institution_logo.dart';

/// Logo plates for the banks or e-wallets of one account [type], plus
/// "Other" for anything not listed. Picking one themes the account with its
/// brand. Shows nothing for types without known institutions (such as Cash).
class InstitutionPicker extends StatelessWidget {
  const InstitutionPicker({
    super.key,
    required this.type,
    required this.selected,
    required this.onChanged,
  });

  final AccountType type;
  final Institution? selected;
  final ValueChanged<Institution?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = Institutions.ofType(type);
    if (options.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    Widget tile({
      required bool isSelected,
      required String label,
      required VoidCallback onTap,
      required Widget child,
      required Color ring,
    }) => Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isSelected
                ? ring.withValues(alpha: 0.18)
                : AppColors.surface.withValues(alpha: 0.6),
            border: Border.all(
              color: isSelected ? ring : AppColors.hairline(0.07),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final i in options)
          tile(
            isSelected: selected?.id == i.id,
            label: i.name,
            ring: i.gradient.first,
            onTap: () => onChanged(selected?.id == i.id ? null : i),
            child: InstitutionLogo(institution: i, height: 34, width: 92),
          ),
        tile(
          isSelected: selected == null,
          label: 'Other',
          ring: AppColors.leafBright,
          onTap: () => onChanged(null),
          child: SizedBox(
            width: 92,
            height: 34,
            child: Center(
              child: Text(
                'Other',
                style: text.titleMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
