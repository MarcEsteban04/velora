import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';
import '../institutions.dart';
import 'institution_logo.dart';

/// A bank-card-style tile for an account. The gradient animates when the type
/// changes, and [countUp] rolls the balance up from zero.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.name,
    required this.type,
    required this.currency,
    required this.balanceMinor,
    this.countUp = false,
    this.obscured = false,
    this.compact = false,
    this.excluded = false,
    this.institution,
  });

  final String name;
  final AccountType type;
  final Currency currency;
  final int balanceMinor;
  final bool countUp;

  /// Hides the balance (for example when "hide balances" is on).
  final bool obscured;

  /// Half-width layout for the Wallet grid: name, type and currency, and a
  /// balance that shrinks to fit.
  final bool compact;

  /// Marks an account that isn't counted in net worth (compact layout only).
  final bool excluded;

  /// When set, the card wears the bank's or e-wallet's brand colours and logo.
  final Institution? institution;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = institution?.gradient ?? type.gradient;
    if (compact) return _buildCompact(context, text, colors);

    return Semantics(
      label:
          '$name, ${type.label} account, '
          'balance ${obscured ? 'hidden' : Money.format(balanceMinor, currency)}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        height: 176,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative rings give the card some depth.
            Positioned(
              right: -40,
              top: -50,
              child: _Ring(size: 170, alpha: 0.12),
            ),
            Positioned(
              right: 30,
              bottom: -70,
              child: _Ring(size: 140, alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (institution case final i?)
                        InstitutionLogo(institution: i, height: 38)
                      else
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(type.icon, color: Colors.white, size: 22),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name.isEmpty ? type.defaultName : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currency.code,
                          style: text.labelMedium?.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'BALANCE',
                    style: text.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 1.6,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: balanceMinor.toDouble()),
                    duration: countUp
                        ? const Duration(milliseconds: 1400)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        obscured
                            ? '${currency.symbol} ••••••'
                            : Money.format(value.round(), currency),
                        style: text.displaySmall?.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    TextTheme text,
    List<Color> colors,
  ) {
    final balance = obscured
        ? '${currency.symbol} ••••••'
        : Money.format(balanceMinor, currency);

    return Semantics(
      label:
          '$name, ${type.label} account, balance '
          '${obscured ? 'hidden' : balance}'
          '${excluded ? ', not counted in net worth' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -46,
              child: _Ring(size: 120, alpha: 0.12),
            ),
            Positioned(
              right: -30,
              bottom: -60,
              child: _Ring(size: 110, alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (institution case final i?) ...[
                    InstitutionLogo(institution: i, height: 28),
                    const SizedBox(height: 8),
                    Text(
                      name.isEmpty ? i.name : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ] else
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(type.icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name.isEmpty ? type.defaultName : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: institution == null ? 8 : 2),
                  Text(
                    excluded
                        ? 'Not in net worth'
                        : '${type.label} · ${currency.code}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BALANCE',
                    style: text.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 1.4,
                      fontSize: 10,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      balance,
                      style: text.displaySmall?.copyWith(fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 18,
        ),
      ),
    );
  }
}
