import '../../transactions/domain/transaction.dart';
import 'receipt.dart';

/// Reads a receipt from recognized text, offline: the store (from the top
/// lines), the total (from the TOTAL / AMOUNT DUE line, never subtotal,
/// cash or change), the date, and item lines.
///
/// Proof of money in (cashback, interest, a refund, "you have received")
/// reads as income, with the amount received.
abstract final class ReceiptTextParser {
  static final _money = RegExp(
    r'(?:₱|php|p)?\s*(\d{1,3}(?:[,\s]\d{3})+|\d+)[.,](\d{2})(?!\d)',
    caseSensitive: false,
  );

  /// Total keywords, strongest first.
  static const _totalWords = [
    'grand total',
    'total amount due',
    'amount due',
    'total due',
    'total amount',
    'net amount',
    'amount paid',
    'total',
  ];

  /// Lines that mention "total" or hold amounts but aren't the total.
  static final _notTotal = RegExp(
    r'sub\s*-?total|total\s*(items?|qty|quantity|discount|savings)|vatable|vat\b|v\.a\.t|change|cash|tender|card|gcash|maya|points|rounding|less:',
    caseSensitive: false,
  );

  /// Words that mean money came in, not went out.
  static final _incoming = RegExp(
    r'cash\s*-?back|interest\s*(earned|credited|income|paid|received)|you\s*(have\s*)?received|received\s*from|money\s*received|refund(ed)?|credited\s*to\s*your|incoming\s*transfer|salary|payroll\s*credit',
    caseSensitive: false,
  );

  /// Where the amount received is labelled, strongest first.
  static const _incomeWords = [
    'amount received',
    'you have received',
    'you received',
    'received',
    'cashback',
    'cash back',
    'interest',
    'refund',
    'credited',
    'amount',
  ];

  static final _notIncome = RegExp(
    r'balance|fee|charge|rate|tax|withheld|available',
    caseSensitive: false,
  );

  static final _noise = RegExp(
    r'receipt|official|invoice|vat\s*reg|\btin\b|\bmin\b|serial|permit|accred|address|tel\b|cashier|terminal|\bpos\b|thank',
    caseSensitive: false,
  );

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static ReceiptScan? parse(String text, {required DateTime now}) {
    final lines = [
      for (final l in text.split(RegExp(r'\r?\n')))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (lines.isEmpty) return null;

    final incoming = _incoming.hasMatch(text);
    final total = (incoming ? _received(lines) : null) ?? _total(lines);
    if (total == null || total <= 0) return null;

    return ReceiptScan(
      totalMinor: total,
      source: ReceiptSource.device,
      kind: incoming ? TransactionKind.income : TransactionKind.expense,
      merchant: _merchant(lines),
      date: _date(text, now),
      items: _items(lines, total),
    );
  }

  static int _minor(RegExpMatch m) =>
      int.parse(m.group(1)!.replaceAll(RegExp(r'[,\s]'), '')) * 100 +
      int.parse(m.group(2)!);

  /// The amount received on proof of money in, from its labelled line.
  static int? _received(List<String> lines) {
    for (final word in _incomeWords) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (!l.contains(word) || _notIncome.hasMatch(l)) continue;
        final here = _money.allMatches(lines[i]).toList();
        if (here.isNotEmpty) return _minor(here.last);
        if (i + 1 < lines.length && !_notIncome.hasMatch(lines[i + 1])) {
          final next = _money.firstMatch(lines[i + 1]);
          if (next != null) return _minor(next);
        }
      }
    }
    return null;
  }

  static int? _total(List<String> lines) {
    for (final word in _totalWords) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (!l.contains(word) || _notTotal.hasMatch(l)) continue;
        final here = _money.allMatches(lines[i]).toList();
        if (here.isNotEmpty) return _minor(here.last);
        // The amount often sits on the next line in narrow receipts.
        if (i + 1 < lines.length) {
          final next = _money.firstMatch(lines[i + 1]);
          if (next != null) return _minor(next);
        }
      }
    }
    // No labelled total: the biggest amount that isn't cash or change.
    int? best;
    for (final l in lines) {
      if (_notTotal.hasMatch(l)) continue;
      for (final m in _money.allMatches(l)) {
        final v = _minor(m);
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  static String? _merchant(List<String> lines) {
    for (final l in lines.take(6)) {
      final letters = RegExp(r'[A-Za-z]').allMatches(l).length;
      if (letters < 3 || letters < l.length * 0.5) continue;
      if (_noise.hasMatch(l) || _money.hasMatch(l)) continue;
      final cleaned = l.replaceAll(RegExp(r'[^A-Za-z0-9&\x27 .-]'), '').trim();
      if (cleaned.length < 3) continue;
      return _title(cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned);
    }
    return null;
  }

  static String _title(String s) => s
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static DateTime? _date(String text, DateTime now) {
    DateTime? valid(int y, int m, int d) {
      if (y < 100) y += 2000;
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      final date = DateTime(y, m, d);
      // Receipts are from the past, and not ancient.
      if (date.isAfter(now) || now.difference(date).inDays > 400) return null;
      return date;
    }

    final iso = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
    if (iso != null) {
      final d = valid(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
      if (d != null) return d;
    }
    final numeric = RegExp(
      r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?!\d)',
    ).firstMatch(text);
    if (numeric != null) {
      final a = int.parse(numeric.group(1)!);
      final b = int.parse(numeric.group(2)!);
      final y = int.parse(numeric.group(3)!);
      // Philippine receipts are usually month first; fall back to day
      // first when that's the only reading that works.
      final d = valid(y, a, b) ?? valid(y, b, a);
      if (d != null) return d;
    }
    final named = RegExp(
      r'(?:(\d{1,2})\s+)?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})?,?\s*(\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      final m = _months[named.group(2)!.toLowerCase()]!;
      final day = int.tryParse(named.group(3) ?? named.group(1) ?? '');
      if (day != null) {
        final d = valid(int.parse(named.group(4)!), m, day);
        if (d != null) return d;
      }
    }
    return null;
  }

  static List<ReceiptItem> _items(List<String> lines, int total) {
    final items = <ReceiptItem>[];
    for (final l in lines) {
      if (items.length >= 6) break;
      final lower = l.toLowerCase();
      if (_notTotal.hasMatch(lower) ||
          _totalWords.any(lower.contains) ||
          _noise.hasMatch(lower)) {
        continue;
      }
      final m = _money.allMatches(l).toList();
      if (m.isEmpty) continue;
      final amount = _minor(m.last);
      if (amount <= 0 || amount >= total) continue;
      final name = l
          .substring(0, m.last.start)
          .replaceAll(RegExp(r'^\d+\s*[xX@]?\s*'), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9&\x27 .-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (RegExp(r'[A-Za-z]{2,}').hasMatch(name)) {
        items.add(ReceiptItem(_title(name), amount));
      }
    }
    return items;
  }
}
