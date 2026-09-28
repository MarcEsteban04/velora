import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../home/application/balance_privacy.dart';
import '../../receipts/presentation/widgets/receipt_image.dart';
import '../application/transaction_providers.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';
import 'category_style.dart';

/// A transaction, read only: what, how much, which accounts, when, the
/// note and the receipt. Changing it is a deliberate step elsewhere (the
/// ⋮ menu in History), so a stray tap never opens an editor.
abstract final class TransactionDetailsSheet {
  static Future<void> show(BuildContext context, Transaction transaction) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DetailsSheet(transaction: transaction),
      );
}

class _DetailsSheet extends ConsumerWidget {
  const _DetailsSheet({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final t = transaction;
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
        a.id: a,
    };
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final hidden = ref.watch(balancesHiddenProvider);

    final account = accounts[t.accountId];
    final toAccount = t.toAccountId == null ? null : accounts[t.toAccountId];
    final category = t.categoryId == null ? null : categories[t.categoryId];
    final currency = Currencies.byCode(account?.currencyCode ?? 'USD');
    final toCurrency = Currencies.byCode(
      toAccount?.currencyCode ?? currency.code,
    );
    final isTransfer = t.kind == TransactionKind.transfer;
    final cross = isTransfer && toCurrency.code != currency.code;

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (category?.iconData ?? Icons.category_rounded);
    final color = isTransfer
        ? TransactionKind.transfer.color
        : (category?.colorValue ?? AppColors.textMuted);
    final title = isTransfer ? 'Transfer' : (category?.name ?? t.kind.label);

    String money(int minor, Currency c) =>
        hidden ? '${c.symbol} ••••' : Money.format(minor, c);
    final amount = money(t.amountMinor, currency);
    final signed = switch (t.kind) {
      TransactionKind.expense => '−$amount',
      TransactionKind.income => '+$amount',
      TransactionKind.transfer => amount,
    };
    final amountColor = switch (t.kind) {
      TransactionKind.income => AppColors.leafBright,
      _ => AppColors.textPrimary,
    };

    final note = t.note?.trim();
    final rows = <(String, String)>[
      ('Type', t.kind.label),
      if (isTransfer) ...[
        ('From', account?.name ?? 'Deleted account'),
        ('To', toAccount?.name ?? 'Deleted account'),
      ] else
        ('Account', account?.name ?? 'Deleted account'),
      if (cross) ...[
        ('Received', money(t.toAmountMinor ?? t.amountMinor, toCurrency)),
        if (!hidden)
          (
            'Rate',
            '${toCurrency.symbol}${NumberFormat('#,##0.00').format(_rate(t, currency, toCurrency))} '
                'per ${currency.symbol}1',
          ),
      ],
      if (!isTransfer) ('Category', category?.name ?? 'None'),
      ('When', DateFormat('EEE, MMM d, y · h:mm a').format(t.occurredAt)),
      if (note != null && note.isNotEmpty) ('Note', note),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          signed,
                          style: text.headlineSmall?.copyWith(
                            fontSize: 26,
                            color: amountColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.hairline(0.07)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, (label, value)) in rows.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.hairline(0.07),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(label, style: text.labelMedium),
                          ),
                          Expanded(
                            child: Text(
                              value,
                              textAlign: TextAlign.right,
                              style: text.titleMedium?.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (t.hasReceipt) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: 'View the receipt',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => ReceiptViewer.show(context, path: t.receiptPath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 160,
                      child: ReceiptImage(path: t.receiptPath, cacheWidth: 720),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _rate(Transaction t, Currency from, Currency to) =>
      ((t.toAmountMinor ?? t.amountMinor) / math.pow(10, to.decimalDigits)) /
      (t.amountMinor / math.pow(10, from.decimalDigits));
}
