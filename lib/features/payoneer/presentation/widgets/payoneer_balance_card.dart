import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/institutions.dart';
import '../../../accounts/presentation/widgets/institution_logo.dart';

/// The balance in the account's currency, what it would be in the bank
/// today, and the two things you do here: withdraw and invoice.
class PayoneerBalanceCard extends StatelessWidget {
  const PayoneerBalanceCard({
    super.key,
    required this.account,
    required this.institution,
    required this.hidden,
    required this.inMain,
    required this.main,
    required this.onWithdraw,
    required this.onInvoice,
    required this.onScan,
  });

  final Account account;
  final Institution? institution;
  final bool hidden;

  /// The balance in [main] after Payoneer's rate, or null when it's
  /// already in [main] or there's no rate yet.
  final int? inMain;
  final Currency main;
  final VoidCallback onWithdraw;
  final VoidCallback onInvoice;

  /// Scan or import an invoice.
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currency = Currencies.byCode(account.currencyCode);
    final colors =
        institution?.gradient ?? const [Color(0xFF2E2F3A), Color(0xFF15161D)];
    const white = Colors.white;

    return Container(
      clipBehavior: Clip.antiAlias,
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
          // Payoneer's spectrum ring, large and faint in the corner.
          const Positioned(
            right: -46,
            top: -46,
            child: _SpectrumRing(size: 170, opacity: 0.34),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (institution != null)
                      InstitutionLogo(institution: institution!, height: 28)
                    else
                      Text(
                        account.name,
                        style: text.titleMedium?.copyWith(color: white),
                      ),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'Scan or import an invoice',
                      excludeSemantics: true,
                      child: Material(
                        color: white.withValues(alpha: 0.14),
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onScan,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.document_scanner_rounded,
                                  size: 16,
                                  color: white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Scan',
                                  style: text.labelMedium?.copyWith(
                                    color: white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        currency.code,
                        style: text.labelMedium?.copyWith(
                          color: white,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'BALANCE',
                  style: text.labelMedium?.copyWith(
                    color: white.withValues(alpha: 0.7),
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hidden
                        ? '${currency.symbol}••••••'
                        : Money.format(account.balanceMinor, currency),
                    style: text.displaySmall?.copyWith(
                      color: white,
                      fontSize: 34,
                    ),
                  ),
                ),
                if (inMain != null)
                  Text(
                    hidden
                        ? '≈ ${main.symbol}•••• in your bank today'
                        : '≈ ${Money.format(inMain!, main)} in your bank today',
                    style: text.bodyMedium?.copyWith(
                      color: white.withValues(alpha: 0.78),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onWithdraw,
                        style: FilledButton.styleFrom(
                          backgroundColor: white,
                          foregroundColor: const Color(0xFF15161D),
                          minimumSize: const Size.fromHeight(46),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.north_east_rounded, size: 18),
                        label: const Text('Withdraw'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onInvoice,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: white,
                          side: BorderSide(color: white.withValues(alpha: 0.4)),
                          minimumSize: const Size.fromHeight(46),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('New invoice'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectrumRing extends StatelessWidget {
  const _SpectrumRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _RingPainter(opacity)),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.12;
    canvas.drawCircle(
      rect.center,
      size.width / 2 - stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: [
            const Color(0xFFFF4A3D),
            const Color(0xFFFFB200),
            const Color(0xFF3CD070),
            const Color(0xFF2AA7FF),
            const Color(0xFF8A4DFF),
            const Color(0xFFFF4A3D),
          ].map((c) => c.withValues(alpha: opacity)).toList(),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.opacity != opacity;
}
