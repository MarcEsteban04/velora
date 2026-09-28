import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';

/// Four equal chips (Cash, Bank, E-wallet, Savings). Onboarding and the
/// account form both use it, so the choice looks the same everywhere.
class AccountTypePicker extends StatelessWidget {
  const AccountTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        for (final (i, type) in AccountType.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SelectableTile(
              selected: selected == type,
              semanticLabel: '${type.label} account',
              onTap: () => onChanged(type),
              padding: const EdgeInsets.symmetric(vertical: 14),
              radius: 18,
              child: Column(
                children: [
                  Icon(
                    type.icon,
                    color: selected == type
                        ? AppColors.leafBright
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
