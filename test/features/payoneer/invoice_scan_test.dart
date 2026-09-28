import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/core/ai/ai_client.dart';
import 'package:velora/core/storage/app_preferences.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/payoneer/application/invoice_import.dart';
import 'package:velora/features/payoneer/application/payoneer_providers.dart';
import 'package:velora/features/payoneer/data/invoice_repository.dart';
import 'package:velora/features/payoneer/domain/invoice.dart';
import 'package:velora/features/payoneer/domain/invoice_scan.dart';
import 'package:velora/features/receipts/domain/receipt.dart';
import 'package:velora/features/transactions/data/transaction_repository.dart';
import 'package:velora/features/receipts/data/receipt_storage.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

final _now = DateTime(2026, 9, 29, 15);

void main() {
  group('the AI reply', () {
    InvoiceScan? parse(String raw) =>
        InvoiceScan.parseAi(raw, now: _now, fallbackCurrency: 'USD');

    test('reads an unpaid invoice', () {
      final s = parse(
        '{"is_invoice": true, "reference": "INV-0012", "client": "Acme '
        'Studio", "amount": 2000, "currency": "usd", "issued": "2026-09-15", '
        '"paid": false, "paid_amount": null, "paid_on": null}',
      )!;
      expect(s.reference, 'INV-0012');
      expect(s.client, 'Acme Studio');
      expect(s.amountMinor, 200000);
      expect(s.currencyCode, 'USD');
      expect(s.issuedOn, DateTime(2026, 9, 15));
      expect(s.paid, isFalse);
    });

    test('reads a payment notice, keeping a sane amount received', () {
      final s = parse(
        '{"is_invoice": true, "amount": "2,000.00", "paid": true, '
        '"paid_amount": 1980, "paid_on": "2026-09-20"}',
      )!;
      expect(s.paid, isTrue);
      expect(s.paidMinor, 198000);
      expect(s.paidOn, DateTime(2026, 9, 20));
      // More received than billed is a misread.
      expect(
        parse(
          '{"is_invoice": true, "amount": 100, "paid": true, '
          '"paid_amount": 150}',
        )!.paidMinor,
        isNull,
      );
    });

    test('not an invoice, no amount, or a future date', () {
      expect(parse('{"is_invoice": false, "amount": 5}'), isNull);
      expect(parse('{"is_invoice": true, "amount": null}'), isNull);
      expect(parse('not json'), isNull);
      expect(
        parse('{"is_invoice": true, "amount": 5, "issued": "2027-01-01"}')!
            .issuedOn,
        isNull,
      );
    });
  });

  test('offline: a Payoneer-style invoice from its text', () {
    final s = InvoiceTextParser.parse(
      [
        'Payoneer',
        'Invoice #INV-0012',
        'Date: Sep 15, 2026',
        'Bill to:',
        'Acme Studio LLC',
        'Web design, September',
        'Subtotal USD 2,000.00',
        'Amount due USD 2,000.00',
      ].join('\n'),
      now: _now,
    )!;
    expect(s.reference, 'INV-0012');
    expect(s.client, 'Acme Studio LLC');
    expect(s.amountMinor, 200000);
    expect(s.currencyCode, 'USD');
    expect(s.issuedOn, DateTime(2026, 9, 15));
    expect(s.paid, isFalse);

    final paid = InvoiceTextParser.parse(
      'Payoneer\nYou have been paid\nPayment received from Acme\n\$1,980.00',
      now: _now,
    )!;
    expect(paid.paid, isTrue);
    expect(paid.amountMinor, 198000);
  });

  test('image types are sent as what they are', () {
    expect(
      AiClient.imageMime(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])),
      'image/png',
    );
    expect(
      AiClient.imageMime(
        Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits),
      ),
      'image/webp',
    );
    expect(
      AiClient.imageMime(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
      'image/jpeg',
    );
  });

  group('logging a scan', () {
    late FakeBackend db;
    late ProviderContainer container;
    late InvoiceActions actions;
    final payoneer = Account(
      id: 'payo',
      name: 'Payoneer',
      type: AccountType.bank,
      currencyCode: 'USD',
      openingBalanceMinor: 0,
      institutionId: 'payoneer',
      createdAt: DateTime(2026),
    );

    setUp(() async {
      db = FakeBackend();
      db.accounts.add(payoneer);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          invoiceRepositoryProvider.overrideWithValue(FakeInvoices(db)),
          transactionRepositoryProvider.overrideWithValue(FakeTransactions(db)),
          receiptStorageProvider.overrideWithValue(FakeReceiptStorage()),
        ],
      );
      addTearDown(container.dispose);
      actions = InvoiceActions(container);
    });

    Future<InvoiceImport> log(InvoiceScan scan) async => logScannedInvoice(
      actions,
      scan: scan,
      account: payoneer,
      existing: await container.read(invoiceRepositoryProvider).fetchAll(),
      today: _now,
      categoryId: 'salary',
    );

    const unpaid = InvoiceScan(
      amountMinor: 200000,
      source: ReceiptSource.ai,
      currencyCode: 'USD',
      reference: 'INV-0012',
      client: 'Acme',
    );
    const paid = InvoiceScan(
      amountMinor: 200000,
      source: ReceiptSource.ai,
      reference: 'inv 0012',
      client: 'Acme',
      paid: true,
      paidMinor: 198000,
    );

    test('a new invoice waits for payment, dated today if undated', () async {
      final r = await log(unpaid);
      expect(r, isA<InvoiceLogged>());
      expect((r as InvoiceLogged).paidTransactionId, isNull);
      expect(db.invoices.single.issuedOn, DateTime(2026, 9, 29));
      expect(db.invoices.single.status, InvoiceStatus.sent);
      expect(db.transactions, isEmpty);
    });

    test('the same number again: paid now marks it, else nothing', () async {
      await log(unpaid);
      expect(await log(unpaid), isA<InvoiceAlreadyLogged>());
      // "inv 0012" is INV-0012, now showing as paid.
      final r = await log(paid);
      expect(r, isA<InvoiceMarkedPaid>());
      expect(db.invoices.single.status, InvoiceStatus.paid);
      final t = db.transactions.single;
      expect(t.kind, TransactionKind.income);
      expect(t.amountMinor, 198000);
      expect(t.categoryId, 'salary');
      expect(db.invoices, hasLength(1));
    });

    test(
      'a paid one never seen before: logged and paid, then undone',
      () async {
        final r = await log(paid);
        expect(r, isA<InvoiceLogged>());
        expect(db.invoices.single.status, InvoiceStatus.paid);
        expect(db.transactions.single.amountMinor, 198000);

        await undoScannedInvoice(actions, r);
        expect(db.invoices, isEmpty);
        expect(db.transactions, isEmpty);
      },
    );

    test('another currency is left for the user to log', () async {
      final r = await log(
        const InvoiceScan(
          amountMinor: 50000,
          source: ReceiptSource.ai,
          currencyCode: 'EUR',
        ),
      );
      expect(r, isA<InvoiceOtherCurrency>());
      expect((r as InvoiceOtherCurrency).currencyCode, 'EUR');
      expect(db.invoices, isEmpty);
    });
  });
}
