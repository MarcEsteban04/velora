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
    occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
  );

  TransactionDraft toDraft() => TransactionDraft(
    kind: kind,
    amountMinor: amountMinor,
    accountId: accountId,
    toAccountId: toAccountId,
    toAmountMinor: toAmountMinor,
    categoryId: categoryId,
    note: note,
    occurredAt: occurredAt,
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
  });

  final TransactionKind kind;
  final int amountMinor;
  final String accountId;
  final String? toAccountId;
  final int? toAmountMinor;
  final String? categoryId;
  final String? note;
  final DateTime occurredAt;

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
      'occurred_at': occurredAt.toUtc().toIso8601String(),
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
