import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/domain/account.dart';
import '../../domain/category.dart';
import '../../domain/transaction.dart';
import '../category_style.dart';

/// One transaction row. Dashboard and History both use it.
///
/// - Expenses show "−₱150.00" in the normal text color: spending is normal,
///   not an alarm.
/// - Income shows "+₱500.00" in green.
/// - Transfers show "Cash → BPI" with a neutral amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.categories,
    required this.hidden,
    this.onTap,
    this.showDate = false,
  });

  final Transaction transaction;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final bool hidden;
  final VoidCallback? onTap;

  /// Recent activity shows the day too; History already groups by day.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final text = Theme.of(context).textTheme;
    final account = accounts[t.accountId];
    final toAccount = t.toAccountId == null ? null : accounts[t.toAccountId];
    final category = t.categoryId == null ? null : categories[t.categoryId];
    final currency = Currencies.byCode(account?.currencyCode ?? 'USD');

    final isTransfer = t.kind == TransactionKind.transfer;
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (category?.iconData ?? Icons.category_rounded);
    final color = isTransfer
        ? TransactionKind.transfer.color
        : (category?.colorValue ?? AppColors.textMuted);

    final note = t.note?.trim();
    final title = (note != null && note.isNotEmpty)
        ? note
        : isTransfer
        ? 'Transfer'
        : (category?.name ?? t.kind.label);
    final when = showDate
        ? DateFormat('MMM d · h:mm a').format(t.occurredAt)
        : DateFormat('h:mm a').format(t.occurredAt);
    final where = isTransfer
        ? '${account?.name ?? 'Account'} → ${toAccount?.name ?? 'Account'}'
        : [
            if (note != null && note.isNotEmpty && category != null)
              category.name,
            account?.name ?? 'Account',
          ].join(' · ');

    final amount = hidden
        ? '${currency.symbol} ••••'
        : Money.format(t.amountMinor, currency);
    final signed = switch (t.kind) {
      TransactionKind.expense => '−$amount',
      TransactionKind.income => '+$amount',
      TransactionKind.transfer => amount,
    };
    final amountColor = switch (t.kind) {
      TransactionKind.income => AppColors.leafBright,
      TransactionKind.expense => AppColors.textPrimary,
      TransactionKind.transfer => AppColors.textSecondary,
    };

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                    Text(
                      '$where · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                signed,
                style: text.titleMedium?.copyWith(
                  fontSize: 15,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
