import '../../accounts/domain/account.dart';
import '../../ask/domain/transaction_parser.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/receipt.dart';

/// Turns a scanned receipt into an expense to confirm: the total, the
/// store as the note, the receipt's day, the usual account, and a category
/// from the AI's pick or from what the store and items say.
ParsedTransaction receiptToTransaction(
  ReceiptScan scan, {
  required List<Account> accounts,
  required List<Category> categories,
  required DateTime now,
  required String accountId,
}) {
  final expense = categories.where(
    (c) => c.kind == TransactionKind.expense && !c.hidden,
  );

  Category? pick() {
    if (scan.category case final name?) {
      final n = name.toLowerCase();
      final hit = expense.where((c) => c.name.toLowerCase() == n).firstOrNull;
      if (hit != null) return hit;
    }
    // Velora's own keywords: "Jollibee" is food, "Shell" is transport...
    final words = [
      scan.merchant,
      ...scan.items.map((i) => i.name),
    ].whereType<String>().join(' ');
    if (words.isNotEmpty) {
      final guess = TransactionParser(
        accounts: accounts,
        categories: categories,
        now: now,
        defaultAccountId: accountId,
      ).parse('spent 1 on $words')?.categoryId;
      if (guess != null) return expense.where((c) => c.id == guess).firstOrNull;
    }
    return expense.where((c) => c.icon == 'other').firstOrNull;
  }

  final d = scan.date;
  final today = DateTime(now.year, now.month, now.day);
  final when = d == null || !DateTime(d.year, d.month, d.day).isBefore(today)
      ? now
      : DateTime(d.year, d.month, d.day, now.hour, now.minute);

  return ParsedTransaction(
    kind: TransactionKind.expense,
    amountMinor: scan.totalMinor,
    accountId: accountId,
    accountGuessed: true,
    categoryId: pick()?.id,
    note: scan.merchant,
    occurredAt: when,
  );
}
