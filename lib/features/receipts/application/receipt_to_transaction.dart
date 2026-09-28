import '../../accounts/domain/account.dart';
import '../../ask/domain/transaction_parser.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/receipt.dart';

/// Turns a scan into a transaction to confirm: an expense for a receipt,
/// income for cashback, interest and the like. The amount, the store (or
/// source) as the note, the day, the usual account, and a category of the
/// same kind from the AI's pick or from what the words say.
ParsedTransaction receiptToTransaction(
  ReceiptScan scan, {
  required List<Account> accounts,
  required List<Category> categories,
  required DateTime now,
  required String accountId,
}) {
  final kind = scan.kind;
  final pool = categories.where((c) => c.kind == kind && !c.hidden);

  Category? pick() {
    if (scan.category case final name?) {
      final n = name.toLowerCase();
      final hit = pool.where((c) => c.name.toLowerCase() == n).firstOrNull;
      if (hit != null) return hit;
    }
    // Velora's own keywords: "Jollibee" is food, "Shell" is transport,
    // "cashback" is a refund...
    final words = [
      scan.merchant,
      ...scan.items.map((i) => i.name),
    ].whereType<String>().join(' ');
    if (words.isNotEmpty) {
      final guess =
          TransactionParser(
                accounts: accounts,
                categories: categories,
                now: now,
                defaultAccountId: accountId,
              )
              .parse(
                kind == TransactionKind.income
                    ? 'received 1 from $words'
                    : 'spent 1 on $words',
              )
              ?.categoryId;
      final hit = pool.where((c) => c.id == guess).firstOrNull;
      if (hit != null) return hit;
    }
    return pool.where((c) => c.icon == 'other').firstOrNull;
  }

  final d = scan.date;
  final today = DateTime(now.year, now.month, now.day);
  final when = d == null || !DateTime(d.year, d.month, d.day).isBefore(today)
      ? now
      : DateTime(d.year, d.month, d.day, now.hour, now.minute);

  return ParsedTransaction(
    kind: kind,
    amountMinor: scan.totalMinor,
    accountId: accountId,
    accountGuessed: true,
    categoryId: pick()?.id,
    note: scan.merchant,
    occurredAt: when,
  );
}
