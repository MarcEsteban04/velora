import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/widgets/account_avatar.dart';
import '../../../transactions/domain/category.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/category_style.dart';
import '../../domain/chat_message.dart';
import '../../domain/transaction_parser.dart';

/// A transaction Velora understood, laid out to check at a glance: amount,
/// category, account and day. "Log it" saves it; "Edit" opens the full
/// editor; once logged, "Undo" takes it back.
class ProposalCard extends StatelessWidget {
  const ProposalCard({
    super.key,
    required this.proposal,
    required this.status,
    required this.accounts,
    required this.categories,
    required this.onConfirm,
    required this.onEdit,
    required this.onUndo,
  });

  final ParsedTransaction proposal;
  final ProposalStatus status;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = proposal;
    final account = accounts[p.accountId];
    final to = p.toAccountId == null ? null : accounts[p.toAccountId];
    final category = p.categoryId == null ? null : categories[p.categoryId];
    final currency = Currencies.byCode(account?.currencyCode ?? 'PHP');
    final tint = switch (p.kind) {
      TransactionKind.expense => AppColors.rust,
      TransactionKind.income => AppColors.leafBright,
      TransactionKind.transfer => AppColors.sky,
    };
    final today = DateUtils.dateOnly(AppClock.now());
    final day = DateUtils.dateOnly(p.occurredAt);
    final when = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('EEE, MMM d').format(day);
    final amount = Money.format(p.amountMinor, currency);
    final done = status == ProposalStatus.saved;
    final closed =
        status == ProposalStatus.undone || status == ProposalStatus.edited;

    Widget row(Widget leading, String label, String value, {String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: leading)),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: text.labelMedium?.copyWith(fontSize: 11),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: value,
                    children: [
                      if (hint != null)
                        TextSpan(
                          text: '  $hint',
                          style: text.labelMedium?.copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: closed ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? AppColors.accentBright : tint.withValues(alpha: 0.35),
            width: done ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.kind.label.toUpperCase(),
                    style: text.labelMedium?.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${switch (p.kind) {
                        TransactionKind.expense => '−',
                        TransactionKind.income => '+',
                        TransactionKind.transfer => '',
                      }}$amount',
                      style: text.headlineSmall?.copyWith(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
            if (p.kind != TransactionKind.transfer)
              row(
                Icon(
                  category?.iconData ?? Icons.category_rounded,
                  size: 18,
                  color: category?.colorValue ?? AppColors.textMuted,
                ),
                'Category',
                category?.name ?? 'Pick one in Edit',
              ),
            row(
              AccountAvatar(account: account, size: 20),
              p.kind == TransactionKind.transfer ? 'From' : 'Account',
              account?.name ?? 'Account',
              hint: p.accountGuessed ? 'your usual' : null,
            ),
            if (p.kind == TransactionKind.transfer)
              row(
                AccountAvatar(account: to, size: 20),
                'To',
                to?.name ?? 'Account',
              ),
            row(
              Icon(Icons.event_rounded, size: 17, color: AppColors.sky),
              'When',
              '$when · ${DateFormat('h:mm a').format(p.occurredAt)}',
            ),
            if (p.note case final n?)
              row(
                Icon(Icons.notes_rounded, size: 17, color: AppColors.textMuted),
                'Note',
                n,
              ),
            const SizedBox(height: 12),
            switch (status) {
              ProposalStatus.pending || ProposalStatus.saving => Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: status == ProposalStatus.saving
                          ? null
                          : onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.hairline(0.16)),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: status == ProposalStatus.saving
                          ? null
                          : onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onBrand,
                        shape: const StadiumBorder(),
                      ),
                      icon: status == ProposalStatus.saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        status == ProposalStatus.saving ? 'Logging…' : 'Log it',
                      ),
                    ),
                  ),
                ],
              ),
              ProposalStatus.saved => Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.accentBright,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Logged',
                      style: text.titleMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.accentBright,
                      ),
                    ),
                  ),
                  TextButton(onPressed: onUndo, child: const Text('Undo')),
                ],
              ),
              ProposalStatus.undone => Text(
                'Undone. Nothing was kept.',
                style: text.labelMedium,
              ),
              ProposalStatus.edited => Text(
                'Opened in the editor.',
                style: text.labelMedium,
              ),
            },
          ],
        ),
      ),
    );
  }
}
