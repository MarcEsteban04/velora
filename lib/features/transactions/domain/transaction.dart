import '../../../core/time/app_clock.dart';

enum TransactionKind { expense, income, transfer }

class Transaction {
  const Transaction({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.accountId,
    required this.occurredAt,
    this.toAccountId,
    this.toAmountMinor,
    this.categoryId,
    this.note,
    this.receiptPath,
  });

  final String id;
  final TransactionKind kind;

  /// Always positive; [kind] gives the direction.
  final int amountMinor;
  final String accountId;
  final String? toAccountId;

  /// Only set for transfers between accounts in different currencies.
  final int? toAmountMinor;
  final String? categoryId;
  final String? note;
  final DateTime occurredAt;

  /// Where its receipt photo is stored, if it has one.
  final String? receiptPath;

  bool get hasReceipt => receiptPath != null;

  factory Transaction.fromRow(Map<String, dynamic> row) => Transaction(
    id: row['id'] as String,
    kind:
        TransactionKind.values.asNameMap()[row['kind'] as String] ??
        TransactionKind.expense,
    amountMinor: (row['amount_minor'] as num).toInt(),
    accountId: row['account_id'] as String,
    toAccountId: row['to_account_id'] as String?,
    toAmountMinor: (row['to_amount_minor'] as num?)?.toInt(),
    categoryId: row['category_id'] as String?,
    note: row['note'] as String?,
    // Tolerates a database that hasn't had the receipts migration yet.
    receiptPath: row['receipt_path'] as String?,
    occurredAt: AppClock.wall(DateTime.parse(row['occurred_at'] as String)),
  );

  /// How much this moved [accountId]'s balance, in its currency: income
  /// in, expenses out, and transfers either way (what arrived, for the
  /// receiving account).
  int changeTo(String accountId) => switch (kind) {
    TransactionKind.income when this.accountId == accountId => amountMinor,
    TransactionKind.expense when this.accountId == accountId => -amountMinor,
    TransactionKind.transfer when toAccountId == accountId =>
      toAmountMinor ?? amountMinor,
    TransactionKind.transfer when this.accountId == accountId => -amountMinor,
    _ => 0,
  };

  TransactionDraft toDraft() => TransactionDraft(
    kind: kind,
    amountMinor: amountMinor,
    accountId: accountId,
    toAccountId: toAccountId,
    toAmountMinor: toAmountMinor,
    categoryId: categoryId,
    note: note,
    occurredAt: occurredAt,
    receiptPath: receiptPath,
  );
}

/// What the entry screen produces. Also used to put a deleted transaction
/// back when the user taps Undo.
class TransactionDraft {
  const TransactionDraft({
    required this.kind,
    required this.amountMinor,
    required this.accountId,
    required this.occurredAt,
    this.toAccountId,
    this.toAmountMinor,
    this.categoryId,
    this.note,
    this.receiptPath,
  });

  final TransactionKind kind;
  final int amountMinor;
  final String accountId;
  final String? toAccountId;
  final int? toAmountMinor;
  final String? categoryId;
  final String? note;
  final DateTime occurredAt;

  /// Only sent when set, so an edit never clears a receipt by accident
  /// (and it works before the receipts migration). Undo uses it to put a
  /// deleted transaction's receipt back.
  final String? receiptPath;

  Map<String, Object?> toRow() {
    final trimmed = note?.trim();
    return {
      'kind': kind.name,
      'amount_minor': amountMinor,
      'account_id': accountId,
      'to_account_id': kind == TransactionKind.transfer ? toAccountId : null,
      'to_amount_minor': kind == TransactionKind.transfer
          ? toAmountMinor
          : null,
      'category_id': kind == TransactionKind.transfer ? null : categoryId,
      'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'occurred_at': AppClock.toUtc(occurredAt).toIso8601String(),
      'receipt_path': ?receiptPath,
    };
  }
}

/// Money in and out over a set of transactions, in one currency's accounts.
/// Transfers move money between the user's own accounts, so they're neither
/// income nor spending.
class FlowSummary {
  const FlowSummary({required this.incomeMinor, required this.spentMinor});

  factory FlowSummary.of(
    Iterable<Transaction> txns, {
    required bool Function(String accountId) inCurrency,
  }) {
    var income = 0;
    var spent = 0;
    for (final t in txns) {
      if (!inCurrency(t.accountId)) continue;
      switch (t.kind) {
        case TransactionKind.income:
          income += t.amountMinor;
        case TransactionKind.expense:
          spent += t.amountMinor;
        case TransactionKind.transfer:
          break;
      }
    }
    return FlowSummary(incomeMinor: income, spentMinor: spent);
  }

  final int incomeMinor;
  final int spentMinor;

  int get netMinor => incomeMinor - spentMinor;
}
