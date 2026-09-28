import '../../../core/time/app_clock.dart';

enum InvoiceStatus { sent, paid, cancelled }

/// A bill sent to a client, in the currency of the account it's paid into.
class Invoice {
  const Invoice({
    required this.id,
    required this.accountId,
    required this.client,
    required this.amountMinor,
    required this.issuedOn,
    required this.status,
    required this.createdAt,
    this.reference,
    this.paidTransactionId,
  });

  factory Invoice.fromRow(Map<String, dynamic> row) => Invoice(
    id: row['id'] as String,
    accountId: row['account_id'] as String,
    client: row['client'] as String,
    reference: row['reference'] as String?,
    amountMinor: (row['amount_minor'] as num).toInt(),
    issuedOn: DateTime.parse(row['issued_on'] as String),
    status:
        InvoiceStatus.values.asNameMap()[row['status'] as String] ??
        InvoiceStatus.sent,
    paidTransactionId: row['paid_transaction_id'] as String?,
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
  );

  final String id;
  final String accountId;
  final String client;

  /// The invoice number, for example "INV-0012".
  final String? reference;

  /// What was billed. What arrived is the paid transaction's amount.
  final int amountMinor;

  /// A calendar date, at midnight.
  final DateTime issuedOn;
  final InvoiceStatus status;
  final String? paidTransactionId;
  final DateTime createdAt;

  bool get isWaiting => status == InvoiceStatus.sent;

  /// "INV-0012 · Acme", or just the client.
  String get title => reference == null ? client : '$reference · $client';

  /// Days since it was sent, as of [now].
  int daysWaiting(DateTime now) =>
      DateTime(now.year, now.month, now.day).difference(issuedOn).inDays;

  InvoiceDraft toDraft() => InvoiceDraft(
    accountId: accountId,
    client: client,
    reference: reference,
    amountMinor: amountMinor,
    issuedOn: issuedOn,
  );
}

class InvoiceDraft {
  const InvoiceDraft({
    required this.accountId,
    required this.client,
    required this.amountMinor,
    required this.issuedOn,
    this.reference,
  });

  final String accountId;
  final String client;
  final String? reference;
  final int amountMinor;
  final DateTime issuedOn;

  Map<String, Object?> toRow() {
    final ref = reference?.trim();
    return {
      'account_id': accountId,
      'client': client.trim(),
      'reference': ref == null || ref.isEmpty ? null : ref,
      'amount_minor': amountMinor,
      'issued_on':
          '${issuedOn.year.toString().padLeft(4, '0')}-'
          '${issuedOn.month.toString().padLeft(2, '0')}-'
          '${issuedOn.day.toString().padLeft(2, '0')}',
    };
  }
}

/// The next invoice number after [previous]: "INV-0012" becomes "INV-0013",
/// keeping the prefix and padding. Null when there's no number to follow.
String? nextInvoiceReference(String? previous) {
  if (previous == null) return null;
  final match = RegExp(r'^(.*?)(\d+)(\D*)$').firstMatch(previous.trim());
  if (match == null) return null;
  final digits = match.group(2)!;
  final next = (int.parse(digits) + 1).toString().padLeft(digits.length, '0');
  return '${match.group(1)}$next${match.group(3)}';
}
