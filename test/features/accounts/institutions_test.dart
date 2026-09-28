import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/accounts/presentation/institutions.dart';

void main() {
  group('Institutions.match', () {
    test('recognises brands in account names', () {
      expect(Institutions.match('Maribank')?.id, 'maribank');
      expect(Institutions.match('maribank savings')?.id, 'maribank');
      expect(Institutions.match('My GCash')?.id, 'gcash');
      expect(Institutions.match('BPI Payroll')?.id, 'bpi');
      expect(Institutions.match('Shopee Pay')?.id, 'shopeepay');
      expect(Institutions.match('PayMaya')?.id, 'maya');
    });

    test('knows Payoneer, which holds dollars', () {
      final p = Institutions.match('Payoneer')!;
      expect(p.isPayoneer, isTrue);
      expect(p.currencyCode, 'USD');
      expect(Institutions.match('BPI')!.currencyCode, isNull);
    });

    test('matches whole words only', () {
      expect(Institutions.match('Mayari Farms'), isNull);
      expect(Institutions.match('Cash'), isNull);
      expect(Institutions.match('Emergency fund'), isNull);
    });
  });

  test('a chosen institution wins over the name', () {
    final a = Account(
      id: 'x',
      name: 'Payroll',
      type: AccountType.bank,
      currencyCode: 'PHP',
      openingBalanceMinor: 0,
      createdAt: DateTime(2026),
      institutionId: 'bpi',
    );
    expect(Institutions.forAccount(a)?.id, 'bpi');
  });

  test('drafts without an institution leave the column out', () {
    const draft = AccountDraft(
      name: 'Cash',
      type: AccountType.cash,
      currencyCode: 'PHP',
      openingBalanceMinor: 0,
    );
    expect(draft.toRow().containsKey('institution'), isFalse);
  });

  test('every logo asset exists, with the exact same letter case', () {
    // Android asset names are case-sensitive, but Windows file lookups
    // aren't, so compare against the real names in the folder.
    for (final i in Institutions.all) {
      final file = File(i.asset);
      final names = file.parent
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toSet();
      expect(names, contains(file.uri.pathSegments.last), reason: i.asset);
    }
  });
}
