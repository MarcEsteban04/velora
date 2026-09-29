import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../accounts/data/account_repository.dart';
import '../../profile/application/main_currency.dart';
import '../../receipts/presentation/widgets/receipt_attachment.dart';
import '../../receipts/presentation/widgets/receipt_image.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_details_sheet.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import 'widgets/day_group.dart';

/// What a transaction card does, the same everywhere it's listed (History,
/// an account's screen): tap for details, and from the menu edit, log
/// again, add or view the receipt, or delete with Undo.
///
/// [hide] and [unhide] let the list drop a deleted row at once (a swiped
/// row must leave the tree right away) and bring it back if the delete
/// fails.
TransactionMenu transactionMenuFor(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<String> hide,
  required ValueChanged<String> unhide,
}) {
  Future<void> delete(Transaction t) async {
    hide(t.id);
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    try {
      await actions.delete(t.id);
      HapticFeedback.mediumImpact();
      toast.show(
        'Transaction deleted',
        tone: ToastTone.info,
        icon: Icons.delete_outline_rounded,
        action: ToastAction('Undo', () => actions.create(t.toDraft())),
      );
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'delete that'),
        tone: ToastTone.error,
      );
      unhide(t.id);
    }
  }

  /// Logs the same transaction again, now.
  Future<void> repeat(Transaction t) async {
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    final currency = Currencies.byCode(
      ref
              .read(accountsProvider)
              .value
              ?.where((a) => a.id == t.accountId)
              .firstOrNull
              ?.currencyCode ??
          ref.read(mainCurrencyProvider).code,
    );
    try {
      final d = t.toDraft();
      final saved = await actions.create(
        TransactionDraft(
          kind: d.kind,
          amountMinor: d.amountMinor,
          accountId: d.accountId,
          toAccountId: d.toAccountId,
          toAmountMinor: d.toAmountMinor,
          categoryId: d.categoryId,
          note: d.note,
          occurredAt: AppClock.now(),
        ),
      );
      HapticFeedback.mediumImpact();
      toast.show(
        'Logged again · ${Money.format(t.amountMinor, currency)}',
        icon: Icons.replay_rounded,
        action: ToastAction('Undo', () => actions.delete(saved.id)),
      );
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'log that'),
        tone: ToastTone.error,
      );
    }
  }

  /// Shows the receipt (to replace or remove), or adds one.
  Future<void> receipt(Transaction t) async {
    final actions = TransactionActions.of(context);
    final toast = Toast.of(context);
    Future<void> attach() async {
      final photo = await chooseReceiptPhoto(context, ref);
      if (photo == null) return;
      try {
        await actions.attachReceipt(t.id, photo);
        toast.show('Receipt attached', icon: Icons.attach_file_rounded);
      } on Object catch (error) {
        toast.error(friendlyError(error, action: 'upload the receipt'));
      }
    }

    if (!t.hasReceipt) return attach();
    final action = await ReceiptViewer.show(
      context,
      path: t.receiptPath,
      canEdit: true,
    );
    if (!context.mounted) return;
    switch (action) {
      case ReceiptViewerAction.replace:
        await attach();
      case ReceiptViewerAction.remove:
        try {
          await actions.removeReceipt(t);
          toast.show(
            'Receipt removed',
            tone: ToastTone.info,
            icon: Icons.delete_outline_rounded,
          );
        } on Object catch (error) {
          toast.error(friendlyError(error, action: 'remove the receipt'));
        }
      case null:
        break;
    }
  }

  return TransactionMenu(
    onView: (t) => TransactionDetailsSheet.show(context, t),
    onEdit: (t) =>
        Navigator.of(context).push(TransactionEntryScreen.route(existing: t)),
    onRepeat: repeat,
    onDelete: delete,
    onReceipt: receipt,
  );
}
