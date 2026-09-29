import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';

/// Equal chips, one per type (Cash, Bank, E-wallet, Savings, Credit).
/// Onboarding and the account form both use it, so the choice looks the
/// same everywhere.
class AccountTypePicker extends StatelessWidget {
  const AccountTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.types = AccountType.values,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  /// Which to offer. Onboarding leaves out credit: the first account is
  /// where money is kept.
  final List<AccountType> types;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        for (final (i, type) in types.indexed) ...[
          if (i > 0) SizedBox(width: types.length > 4 ? 6 : 8),
          Expanded(
            child: SelectableTile(
              selected: selected == type,
              semanticLabel: '${type.label} account',
              onTap: () => onChanged(type),
              padding: EdgeInsets.symmetric(
                vertical: 14,
                horizontal: types.length > 4 ? 2 : 0,
              ),
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
                      fontSize: types.length > 4 ? 11 : null,
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
