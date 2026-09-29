import 'package:flutter/material.dart';

import '../domain/account.dart';
import 'account_type_style.dart';

/// A bank or e-wallet Velora knows: its logo and the brand colours used to
/// theme its cards.
class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.type,
    required this.asset,
    required this.gradient,
    required this.aliases,
    this.darkPlate = false,
    this.currencyCode,
    this.international = false,
  });

  /// Stored in `accounts.institution`.
  final String id;
  final String name;
  final AccountType type;
  final String asset;
  final List<Color> gradient;

  /// Lower-case words that identify it in an account name.
  final List<String> aliases;

  /// Logos with white lettering sit on a dark plate instead of a light one.
  final bool darkPlate;

  /// The currency a new account here usually holds, when it isn't the
  /// user's main one (Payoneer balances are in US dollars).
  final String? currencyCode;

  /// A bank outside the Philippines, such as Payoneer. Listed under
  /// "International bank" and labelled that way.
  final bool international;

  bool get isPayoneer => id == 'payoneer';
}

/// How an account reads in lists: "International bank" for one, else its
/// type ("Bank", "E-wallet"...).
String accountKindLabel(AccountType type, Institution? institution) =>
    (institution?.international ?? false) ? 'International bank' : type.label;

abstract final class Institutions {
  static const _dir = 'assets/images/accounts';

  static const all = <Institution>[
    Institution(
      id: 'bpi',
      name: 'BPI',
      type: AccountType.bank,
      asset: '$_dir/bpi.png',
      gradient: [Color(0xFFB3121A), Color(0xFF6B0A0F)],
      aliases: ['bpi', 'bank of the philippine islands'],
    ),
    Institution(
      id: 'maribank',
      name: 'Maribank',
      type: AccountType.bank,
      asset: '$_dir/maribank.png',
      gradient: [Color(0xFFF2600C), Color(0xFFB43C06)],
      aliases: ['maribank', 'mari bank'],
    ),
    Institution(
      id: 'gotyme',
      name: 'GoTyme',
      type: AccountType.bank,
      asset: '$_dir/gotyme.png',
      gradient: [Color(0xFF3A4566), Color(0xFF151A2C)],
      aliases: ['gotyme', 'go tyme'],
    ),
    Institution(
      id: 'gcash',
      name: 'GCash',
      type: AccountType.eWallet,
      asset: '$_dir/gcash.png',
      gradient: [Color(0xFF1466F2), Color(0xFF0A2FA8)],
      aliases: ['gcash', 'g cash'],
    ),
    Institution(
      id: 'maya',
      name: 'Maya',
      type: AccountType.eWallet,
      asset: '$_dir/maya.png',
      gradient: [Color(0xFF12C77E), Color(0xFF06734A)],
      aliases: ['maya', 'paymaya'],
    ),
    Institution(
      id: 'shopeepay',
      name: 'ShopeePay',
      type: AccountType.eWallet,
      asset: '$_dir/shopeepay.png',
      gradient: [Color(0xFFF2542D), Color(0xFFB5321A)],
      aliases: ['shopeepay', 'shopee pay', 'shopee'],
    ),
    Institution(
      id: 'billease',
      name: 'BillEase',
      type: AccountType.eWallet,
      asset: '$_dir/billease.png',
      gradient: [Color(0xFFF03A3A), Color(0xFF9E1B1B)],
      aliases: ['billease', 'bill ease'],
      darkPlate: true,
    ),
    Institution(
      id: 'payoneer',
      name: 'Payoneer',
      type: AccountType.bank,
      asset: '$_dir/payoneer.png',
      gradient: [Color(0xFF2E2F3A), Color(0xFF15161D)],
      aliases: ['payoneer'],
      currencyCode: 'USD',
      international: true,
    ),
  ];

  static Institution? byId(String? id) =>
      id == null ? null : all.where((i) => i.id == id).firstOrNull;

  /// Institutions of [type]; with [international], only those inside or
  /// outside the Philippines.
  static List<Institution> ofType(AccountType type, {bool? international}) =>
      all
          .where(
            (i) =>
                i.type == type &&
                (international == null || i.international == international),
          )
          .toList();

  /// The institution an account name refers to, if any, for example
  /// "Maribank savings" → Maribank. It matches whole words, so "Mayari
  /// Farms" isn't taken for Maya.
  static Institution? match(String name) => matchIn(all, name);

  /// Brands people owe money to but don't keep an account with, for
  /// debts. Not offered when adding an account.
  static const lenders = <Institution>[
    Institution(
      id: 'spaylater',
      name: 'SPayLater',
      type: AccountType.eWallet,
      asset: '$_dir/spaylater.png',
      gradient: [Color(0xFFEE4D2D), Color(0xFFB8321A)],
      aliases: [
        'spaylater',
        'spay later',
        'shopee paylater',
        'shopee pay later',
      ],
    ),
  ];

  /// The brand a debt's name refers to: a lender (SPayLater), or a bank
  /// or e-wallet ("BPI credit card", "BillEase").
  static Institution? forDebt(String name) =>
      matchIn(lenders, name) ?? match(name);

  static Institution? matchIn(Iterable<Institution> list, String name) {
    final normalized =
        ' ${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
    for (final i in list) {
      for (final alias in i.aliases) {
        if (normalized.contains(' $alias ')) return i;
      }
    }
    return null;
  }

  /// The chosen institution, else one recognised from the name.
  static Institution? forAccount(Account a) =>
      byId(a.institutionId) ?? match(a.name);
}
