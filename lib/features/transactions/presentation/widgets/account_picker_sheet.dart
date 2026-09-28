import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/widgets/account_avatar.dart';

/// Pick an account, with each one's live balance so you know where the money
/// will come from.
class AccountPickerSheet extends StatelessWidget {
  const AccountPickerSheet({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.title,
    this.disabledId,
  });

  final List<Account> accounts;
  final String? selectedId;
  final String title;

  /// For transfers: the other side, which can't be picked again.
  final String? disabledId;

  static Future<Account?> show(
    BuildContext context, {
    required List<Account> accounts,
    required String? selectedId,
    String title = 'Choose account',
    String? disabledId,
  }) => showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AccountPickerSheet(
      accounts: accounts,
      selectedId: selectedId,
      title: title,
      disabledId: disabledId,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: text.headlineSmall),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final a in accounts)
                    Builder(
                      builder: (context) {
                        final currency = Currencies.byCode(a.currencyCode);
                        final disabled = a.id == disabledId;
                        return ListTile(
                          enabled: !disabled,
                          onTap: () => Navigator.pop(context, a),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: AccountAvatar(account: a, size: 42),
                          title: Text(a.name, style: text.titleMedium),
                          subtitle: Text(
                            disabled
                                ? 'Already chosen'
                                : Money.format(a.balanceMinor, currency),
                            style: text.labelMedium,
                          ),
                          trailing: a.id == selectedId
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.leafBright,
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
