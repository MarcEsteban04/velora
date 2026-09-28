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

/// What was read off a receipt.
class ReceiptScan {
  const ReceiptScan({
    required this.totalMinor,
    required this.source,
    this.merchant,
    this.date,
    this.category,
    this.items = const [],
  });

  /// The amount paid, in minor units.
  final int totalMinor;
  final ReceiptSource source;
  final String? merchant;
  final DateTime? date;

  /// A category name suggested by the AI, matched to the user's own later.
  final String? category;
  final List<ReceiptItem> items;
}
