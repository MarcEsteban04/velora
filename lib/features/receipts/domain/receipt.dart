import '../../transactions/domain/transaction.dart';

/// Where a receipt's details came from.
enum ReceiptSource {
  /// Read by the AI from the photo.
  ai,

  /// Read by on-device text recognition, offline.
  device,
}

class ReceiptItem {
  const ReceiptItem(this.name, this.amountMinor);

  final String name;
  final int amountMinor;
}

/// What was read off a receipt, or off proof of money coming in (cashback,
/// interest, a refund, a "you have received" notice).
class ReceiptScan {
  const ReceiptScan({
    required this.totalMinor,
    required this.source,
    this.kind = TransactionKind.expense,
    this.merchant,
    this.date,
    this.category,
    this.items = const [],
  });

  /// The amount paid, or received, in minor units.
  final int totalMinor;
  final ReceiptSource source;

  /// Expense for money out, income for money in.
  final TransactionKind kind;

  /// The store, or for money in, where it came from.
  final String? merchant;
  final DateTime? date;

  /// A category name suggested by the AI, matched to the user's own later.
  final String? category;
  final List<ReceiptItem> items;

  bool get isIncome => kind == TransactionKind.income;

  /// The same scan read the other way round (the user corrected it). The
  /// AI's category was for the old kind, so it's dropped.
  ReceiptScan withKind(TransactionKind kind) => ReceiptScan(
    totalMinor: totalMinor,
    source: source,
    kind: kind,
    merchant: merchant,
    date: date,
    category: kind == this.kind ? category : null,
    items: items,
  );
}

/// The user's category names, for the AI to pick from.
typedef ReceiptCategories = ({List<String> expense, List<String> income});
