import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/money/currency.dart';
import '../../../core/time/app_clock.dart';
import '../../receipts/data/receipt_reader.dart';

/// A screenshot from a card or pay-later app, read.
sealed class DebtScan {
  const DebtScan();
}

/// Something bought on the credit line, maybe over [installments] months.
final class DebtPurchase extends DebtScan {
  const DebtPurchase({
    required this.totalMinor,
    this.installments = 1,
    this.monthlyMinor,
    this.item,
    this.merchant,
    this.date,
  });

  /// What it adds to the debt: every installment together (fees and all)
  /// when the screen shows them, else the price.
  final int totalMinor;
  final int installments;
  final int? monthlyMinor;
  final String? item;
  final String? merchant;
  final DateTime? date;

  /// "Wireless earbuds · Shopee".
  String? get note {
    final parts = [?item, ?merchant];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// A bill or dashboard: what's due, and what the credit line looks like.
/// A list of monthly bills ("My Bill") fills [bills].
final class DebtBill extends DebtScan {
  const DebtBill({
    this.dueMinor,
    this.dueOn,
    this.creditLimitMinor,
    this.availableMinor,
    this.outstandingMinor,
    this.bills = const [],
  });

  final int? dueMinor;
  final DateTime? dueOn;
  final int? creditLimitMinor;
  final int? availableMinor;

  /// Everything owed on it, per the app.
  final int? outstandingMinor;

  /// Every bill the screen lists, soonest due first.
  final List<ScannedBill> bills;

  /// The unpaid bills to add: the listed ones, and the one due when it
  /// isn't among them.
  List<ScannedBill> get unpaidBills {
    final list = bills.where((b) => !b.paid).toList();
    if ((dueMinor, dueOn) case (final due?, final on?)
        when due > 0 && bills.every((b) => b.dueOn != on)) {
      list.add(ScannedBill(amountMinor: due, dueOn: on));
    }
    return list..sort((a, b) => a.dueOn.compareTo(b.dueOn));
  }

  bool get isEmpty =>
      dueMinor == null &&
      creditLimitMinor == null &&
      availableMinor == null &&
      outstandingMinor == null &&
      bills.isEmpty;
}

/// One month's bill from a list of them.
final class ScannedBill {
  const ScannedBill({
    required this.amountMinor,
    required this.dueOn,
    this.paid = false,
  });

  final int amountMinor;
  final DateTime dueOn;
  final bool paid;
}

abstract interface class DebtScanReader {
  Future<DebtScan?> read(
    ReceiptPhoto page, {
    required String debtName,
    required String currencyCode,
  });
}

/// The AI reads it (text recognition alone can't tell a checkout from a
/// statement reliably).
class AiDebtScanReader implements DebtScanReader {
  const AiDebtScanReader();

  @override
  Future<DebtScan?> read(
    ReceiptPhoto page, {
    required String debtName,
    required String currencyCode,
  }) async {
    if (!AiClient.isConfigured) return null;
    final now = AppClock.now();
    final raw = await AiClient.complete(
      system: prompt(debtName: debtName, today: now),
      messages: const [('user', 'Read this.')],
      image: page.bytes,
      json: true,
      maxTokens: 900,
      temperature: 0.1,
    );
    return raw == null
        ? null
        : parse(raw, now: now, currencyCode: currencyCode);
  }

  static String prompt({required String debtName, required DateTime today}) => [
    'You read screenshots from credit card and pay-later apps (like',
    'SPayLater or BillEase) for a budgeting app in the Philippines. This',
    'one is about the user\'s "$debtName".',
    'Reply with JSON only, exactly this shape:',
    '{"type": "purchase" | "bill" | "other", "item": string | null,',
    '"merchant": string | null, "amount": number | null,',
    '"installments": number | null, "monthly": number | null,',
    '"date": "YYYY-MM-DD" | null, "amount_due": number | null,',
    '"due_date": "YYYY-MM-DD" | null, "credit_limit": number | null,',
    '"available_credit": number | null, "outstanding": number | null,',
    '"bills": [{"amount": number, "due_date": "YYYY-MM-DD", "paid": boolean}]',
    '| null}',
    'type is "purchase" for an order, checkout or transaction paid with',
    'the credit line; "bill" for a statement, bill or account page',
    'showing what is due, the limit or what is available; else "other".',
    'For a purchase: item (a few words) and merchant, amount (the price',
    'charged), installments (number of months; 1 if paid in full on the',
    'next bill) and monthly (the per-month amount, if shown), and date.',
    'For a bill: amount_due, due_date, credit_limit, available_credit and',
    'outstanding (total owed), whichever are shown. A list of monthly bills',
    '(like "My Bill": Oct, Nov, Dec, each with an amount, a due date and',
    'Unpaid or Paid) is a "bill" too: put every one in bills, and the',
    'soonest unpaid one in amount_due and due_date. Else bills is null.',
    'Amounts are plain numbers like 1250.50. Today is '
        '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}.',
  ].join(' ');

  static DebtScan? parse(
    String raw, {
    required DateTime now,
    required String currencyCode,
  }) {
    Object? j;
    try {
      j = jsonDecode(raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''));
    } on FormatException {
      return null;
    }
    if (j is! Map) return null;
    final digits = Currencies.byCode(currencyCode).decimalDigits;
    int? minor(Object? v) {
      final n = switch (v) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')),
        _ => null,
      };
      if (n == null || n < 0 || n > 1e9) return null;
      return (n * math.pow(10, digits)).round();
    }

    String? str(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      if (t.isEmpty || t.toLowerCase() == 'null') return null;
      return t.length > 40 ? t.substring(0, 40) : t;
    }

    DateTime? day(Object? v, {bool future = false}) {
      if (v is! String) return null;
      final d = DateTime.tryParse(v);
      if (d == null) return null;
      final gap = d.difference(now).inDays;
      if (!future && d.isAfter(now)) return null;
      if (gap.abs() > 400) return null;
      return DateTime(d.year, d.month, d.day);
    }

    switch (j['type']) {
      case 'purchase':
        final price = minor(j['amount']);
        final monthly = minor(j['monthly']);
        final n = switch (j['installments']) {
          final num v when v >= 1 && v <= 60 => v.round(),
          _ => 1,
        };
        final total = monthly != null && monthly > 0 && n > 1
            ? monthly * n
            : price;
        if (total == null || total <= 0) return null;
        return DebtPurchase(
          totalMinor: total,
          installments: n,
          monthlyMinor: n > 1 ? (monthly ?? total ~/ n) : null,
          item: str(j['item']),
          merchant: str(j['merchant']),
          date: day(j['date']),
        );
      case 'bill':
        final bill = DebtBill(
          dueMinor: minor(j['amount_due']),
          dueOn: day(j['due_date'], future: true),
          creditLimitMinor: switch (minor(j['credit_limit'])) {
            final l? when l > 0 => l,
            _ => null,
          },
          availableMinor: minor(j['available_credit']),
          outstandingMinor: minor(j['outstanding']),
          bills: [
            if (j['bills'] case final List list)
              for (final b in list.take(24))
                if (b case {'amount': final a, 'due_date': final d})
                  if ((minor(a), day(d, future: true))
                      case (final amount?, final on?) when amount > 0)
                    ScannedBill(
                      amountMinor: amount,
                      dueOn: on,
                      paid: b['paid'] == true,
                    ),
          ]..sort((a, b) => a.dueOn.compareTo(b.dueOn)),
        );
        return bill.isEmpty ? null : bill;
      default:
        return null;
    }
  }
}

final debtScanReaderProvider = Provider<DebtScanReader>(
  (ref) => const AiDebtScanReader(),
);
