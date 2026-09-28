import 'package:flutter/material.dart';

import '../../domain/account.dart';
import '../account_type_style.dart';
import '../institutions.dart';
import 'institution_logo.dart';

/// How an account appears in lists, pickers and the entry screen: its bank's
/// or e-wallet's logo when known, otherwise a gradient tile with the type
/// icon.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.size = 44});

  final Account? account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final institution = a == null ? null : Institutions.forAccount(a);
    if (institution != null) {
      return InstitutionLogo(
        institution: institution,
        height: size * 0.72,
        width: size * 1.6,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: a == null ? null : LinearGradient(colors: a.type.gradient),
        color: a == null ? const Color(0xFF1F1B3A) : null,
      ),
      child: Icon(
        a?.type.icon ?? Icons.add_rounded,
        color: Colors.white,
        size: size * 0.48,
      ),
    );
  }
}
