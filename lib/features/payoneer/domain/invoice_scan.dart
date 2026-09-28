import 'dart:convert';
import 'dart:math' as math;

import '../../../core/money/currency.dart';
import '../../receipts/domain/receipt.dart';

/// What was read off an invoice or a payment notice: the invoice itself,
/// and whether it says the money has already arrived.
class InvoiceScan {
  const InvoiceScan({
    required this.amountMinor,
    required this.source,
    this.currencyCode,
    this.reference,
    this.client,
    this.issuedOn,
    this.paid = false,
    this.paidMinor,
    this.paidOn,
  });

  /// What was billed, in minor units of [currencyCode] (or of the account's
  /// currency when the document doesn't say).
  final int amountMinor;
  final ReceiptSource source;
  final String? currencyCode;

  /// The invoice number, like "INV-0012".
  final String? reference;

  /// Who was billed: the customer, never the user.
  final String? client;
  final DateTime? issuedOn;

  /// The document shows the payment went through.
  final bool paid;

  /// What arrived after fees, when the document says.
  final int? paidMinor;
  final DateTime? paidOn;

  /// Reads the AI's JSON reply. Null when it isn't an invoice or there's no
  /// amount. [fallbackCurrency] sets the decimals when the document names
  /// none.
  static InvoiceScan? parseAi(
    String raw, {
    required DateTime now,
    required String fallbackCurrency,
  }) {
    Object? j;
    try {
      j = jsonDecode(raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''));
    } on FormatException {
      return null;
    }
    if (j is! Map || j['is_invoice'] == false) return null;

    double? number(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')),
      _ => null,
    };
    String? str(Object? v, int max) {
      if (v is! String) return null;
      final t = v.trim();
      if (t.isEmpty || t.toLowerCase() == 'null') return null;
      return t.length > max ? t.substring(0, max) : t;
    }

    DateTime? day(Object? v) {
      if (v is! String) return null;
      final d = DateTime.tryParse(v);
      if (d == null || d.isAfter(now) || now.difference(d).inDays > 800) {
        return null;
      }
      return DateTime(d.year, d.month, d.day);
    }

    final code = switch (str(j['currency'], 3)?.toUpperCase()) {
      final c? when RegExp(r'^[A-Z]{3}$').hasMatch(c) => c,
      _ => null,
    };
    final digits = Currencies.byCode(code ?? fallbackCurrency).decimalDigits;
    int? minor(Object? v) => switch (number(v)) {
      final n? when n > 0 && n < 1e9 => (n * math.pow(10, digits)).round(),
      _ => null,
    };

    final amount = minor(j['amount']);
    if (amount == null) return null;
    final paid = j['paid'] == true;
    final paidMinor = paid ? minor(j['paid_amount']) : null;
    return InvoiceScan(
      amountMinor: amount,
      source: ReceiptSource.ai,
      currencyCode: code,
      reference: str(j['reference'], 40),
      client: str(j['client'], 40),
      issuedOn: day(j['issued']),
      paid: paid,
      // A "paid" amount above the bill is a misread, not a tip.
      paidMinor: paidMinor != null && paidMinor <= amount ? paidMinor : null,
      paidOn: paid ? day(j['paid_on']) : null,
    );
  }
}

/// Reads an invoice from recognized text, offline: the number, the total
/// (amount due, total), the client (under "Bill to"), the date, and
/// whether it's marked paid.
abstract final class InvoiceTextParser {
  static final _money = RegExp(
    r'(?:US\$|\$|USD|EUR|€|GBP|£|PHP|₱)?\s*(\d{1,3}(?:[,\s]\d{3})+|\d+)[.,](\d{2})(?!\d)',
    caseSensitive: false,
  );
  static final _reference = RegExp(
    r'invoice\s*(?:no\.?|number|num\.?|#)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{2,})',
    caseSensitive: false,
  );
  static const _totalWords = [
    'amount due',
    'total due',
    'balance due',
    'amount paid',
    'total amount',
    'grand total',
    'total',
    'amount',
  ];
  static final _billTo = RegExp(
    // "To" only with a colon, so "Total" isn't read as a client.
    r'^(?:bill(?:ed)?\s*to|client|customer|to(?=\s*:))\s*:?\s*(.*)$',
    caseSensitive: false,
  );
  static final _paid = RegExp(
    r'\bpaid\b|payment\s+(?:received|completed|successful)|you(?:\x27ve| have)\s+been\s+paid',
    caseSensitive: false,
  );
  static final _unpaid = RegExp(
    r'\bunpaid\b|amount\s+due|due\s+date',
    caseSensitive: false,
  );

  static InvoiceScan? parse(String text, {required DateTime now}) {
    final lines = [
      for (final l in text.split(RegExp(r'\r?\n')))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (lines.isEmpty) return null;
    final amount = _amount(lines);
    if (amount == null || amount <= 0) return null;

    String? reference;
    for (final l in lines) {
      final m = _reference.firstMatch(l);
      if (m != null && RegExp(r'\d').hasMatch(m.group(1)!)) {
        reference = m.group(1)!.toUpperCase();
        break;
      }
    }

    String? client;
    for (var i = 0; i < lines.length; i++) {
      final m = _billTo.firstMatch(lines[i]);
      if (m == null) continue;
      final rest = m.group(1)!.trim();
      client = rest.isNotEmpty
          ? rest
          : (i + 1 < lines.length ? lines[i + 1] : null);
      break;
    }

    final lower = text.toLowerCase();
    final currency = lower.contains('eur') || text.contains('€')
        ? 'EUR'
        : lower.contains('gbp') || text.contains('£')
        ? 'GBP'
        : lower.contains('php') || text.contains('₱')
        ? 'PHP'
        : lower.contains('usd') || text.contains(r'$')
        ? 'USD'
        : null;

    return InvoiceScan(
      amountMinor: amount,
      source: ReceiptSource.device,
      currencyCode: currency,
      reference: reference,
      client: client == null || client.length < 2
          ? null
          : (client.length > 40 ? client.substring(0, 40) : client),
      issuedOn: _date(text, now),
      paid: _paid.hasMatch(text) && !_unpaid.hasMatch(text),
    );
  }

  static int _minor(RegExpMatch m) =>
      int.parse(m.group(1)!.replaceAll(RegExp(r'[,\s]'), '')) * 100 +
      int.parse(m.group(2)!);

  static int? _amount(List<String> lines) {
    for (final word in _totalWords) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (!l.contains(word) || l.contains('sub')) continue;
        final here = _money.allMatches(lines[i]).toList();
        if (here.isNotEmpty) return _minor(here.last);
        if (i + 1 < lines.length) {
          final next = _money.firstMatch(lines[i + 1]);
          if (next != null) return _minor(next);
        }
      }
    }
    int? best;
    for (final l in lines) {
      for (final m in _money.allMatches(l)) {
        final v = _minor(m);
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static DateTime? _date(String text, DateTime now) {
    DateTime? ok(int y, int m, int d) {
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      final date = DateTime(y, m, d);
      if (date.isAfter(now) || now.difference(date).inDays > 800) return null;
      return date;
    }

    final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (iso != null) {
      return ok(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final named = RegExp(r'([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})')
        .firstMatch(text);
    if (named != null) {
      final m = _months[named.group(1)!.toLowerCase()];
      if (m != null) {
        return ok(int.parse(named.group(3)!), m, int.parse(named.group(2)!));
      }
    }
    return null;
  }
}
