import '../../accounts/domain/account.dart';
import '../domain/invoice.dart';
import '../domain/invoice_scan.dart';
import 'payoneer_providers.dart';

/// What logging a scanned invoice did.
sealed class InvoiceImport {
  const InvoiceImport();
}

/// A new invoice; [paidTransactionId] is set when the document showed it
/// already paid and the salary was logged too.
final class InvoiceLogged extends InvoiceImport {
  const InvoiceLogged(this.invoice, {this.paidTransactionId});

  final Invoice invoice;
  final String? paidTransactionId;
}

/// It was already waiting; the document shows it paid, so it's marked paid.
final class InvoiceMarkedPaid extends InvoiceImport {
  const InvoiceMarkedPaid(this.invoice, this.transactionId);

  final Invoice invoice;
  final String transactionId;
}

/// Nothing new: this invoice is logged already.
final class InvoiceAlreadyLogged extends InvoiceImport {
  const InvoiceAlreadyLogged(this.invoice);

  final Invoice invoice;
}

/// In another currency than the account; not logged automatically, since
/// the amount would be wrong.
final class InvoiceOtherCurrency extends InvoiceImport {
  const InvoiceOtherCurrency(this.currencyCode);

  final String currencyCode;
}

/// Logs a scanned invoice on [account], without duplicating one already in
/// [existing] (same number, or same client, amount and date).
Future<InvoiceImport> logScannedInvoice(
  InvoiceActions actions, {
  required InvoiceScan scan,
  required Account account,
  required List<Invoice> existing,
  required DateTime today,
  String? categoryId,
}) async {
  final code = scan.currencyCode;
  if (code != null && code != account.currencyCode) {
    return InvoiceOtherCurrency(code);
  }

  // "INV-0012", "inv 0012" and "#INV0012" are the same invoice.
  String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final mine = existing.where(
    (i) => i.accountId == account.id && i.status != InvoiceStatus.cancelled,
  );
  final match = mine.where((i) {
    if (scan.reference != null && i.reference != null) {
      return norm(scan.reference!) == norm(i.reference!);
    }
    return i.amountMinor == scan.amountMinor &&
        scan.issuedOn != null &&
        i.issuedOn == scan.issuedOn &&
        (scan.client == null ||
            i.client.toLowerCase() == scan.client!.toLowerCase());
  }).firstOrNull;

  Future<String> pay(Invoice invoice) => actions.markPaid(
    invoice,
    amountMinor: scan.paidMinor ?? scan.amountMinor,
    paidAt: _noon(scan.paidOn ?? scan.issuedOn ?? today, today),
    categoryId: categoryId,
  );

  if (match != null) {
    if (scan.paid && match.isWaiting) {
      return InvoiceMarkedPaid(match, await pay(match));
    }
    return InvoiceAlreadyLogged(match);
  }

  final invoice = await actions.create(
    InvoiceDraft(
      accountId: account.id,
      client: scan.client ?? 'Client',
      reference: scan.reference,
      amountMinor: scan.amountMinor,
      issuedOn: scan.issuedOn ?? DateTime(today.year, today.month, today.day),
    ),
  );
  if (!scan.paid) return InvoiceLogged(invoice);
  return InvoiceLogged(invoice, paidTransactionId: await pay(invoice));
}

/// Takes back what [logScannedInvoice] did.
Future<void> undoScannedInvoice(
  InvoiceActions actions,
  InvoiceImport result,
) async {
  switch (result) {
    case InvoiceLogged(:final invoice, :final paidTransactionId):
      if (paidTransactionId != null) await actions.undoPaid(paidTransactionId);
      await actions.delete(invoice.id);
    case InvoiceMarkedPaid(:final transactionId):
      await actions.undoPaid(transactionId);
    case InvoiceAlreadyLogged() || InvoiceOtherCurrency():
      break;
  }
}

/// A past day at noon, or right now for today.
DateTime _noon(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  return d == t ? today : DateTime(d.year, d.month, d.day, 12);
}
