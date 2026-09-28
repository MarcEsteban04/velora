import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_button.dart';
import '../../data/account_repository.dart';
import '../../domain/account.dart';
import '../account_form_screen.dart';
import '../account_type_style.dart';
import 'account_card.dart';

/// Everything about one account, with Edit and a confirmed Delete.
class AccountDetailsSheet extends ConsumerStatefulWidget {
  const AccountDetailsSheet({
    super.key,
    required this.account,
    required this.defaultCurrency,
    required this.hidden,
  });

  final Account account;
  final Currency defaultCurrency;
  final bool hidden;

  static Future<void> show(
    BuildContext context, {
    required Account account,
    required Currency defaultCurrency,
    required bool hidden,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AccountDetailsSheet(
      account: account,
      defaultCurrency: defaultCurrency,
      hidden: hidden,
    ),
  );

  @override
  ConsumerState<AccountDetailsSheet> createState() =>
      _AccountDetailsSheetState();
}

class _AccountDetailsSheetState extends ConsumerState<AccountDetailsSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final a = widget.account;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Delete “${a.name}”?'),
        content: const Text(
          'This removes the account for good. It can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rust),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).delete(a.id);
      ref.invalidate(accountsProvider);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('“${a.name}” deleted')));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(error, action: 'delete the account')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final currency = Currencies.byCode(a.currencyCode);
    final text = Theme.of(context).textTheme;
    final rows = [
      ('Type', a.type.label),
      ('Currency', '${currency.code} · ${currency.name}'),
      (
        'Starting balance',
        widget.hidden
            ? '${currency.symbol} ••••••'
            : Money.format(a.openingBalanceMinor, currency),
      ),
      ('Added', DateFormat('MMM d, y').format(a.createdAt.toLocal())),
      ('In net worth', a.includeInNetWorth ? 'Yes' : 'No'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountCard(
              name: a.name,
              type: a.type,
              currency: currency,
              balanceMinor: a.balanceMinor,
              obscured: widget.hidden,
            ),
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Text(label, style: text.bodyMedium),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            PressableButton(
              label: 'Edit account',
              icon: Icons.edit_rounded,
              onPressed: _deleting
                  ? null
                  : () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        AccountFormScreen.route(
                          defaultCurrency: widget.defaultCurrency,
                          account: a,
                        ),
                      );
                    },
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _deleting ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.rust),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(_deleting ? 'Deleting…' : 'Delete account'),
            ),
          ],
        ),
      ),
    );
  }
}
