import 'package:flutter/material.dart';

import '../institutions.dart';

/// A bank or e-wallet logo on a plate, so every logo reads on any card:
/// light for dark lettering, dark for white lettering (such as BillEase).
class InstitutionLogo extends StatelessWidget {
  const InstitutionLogo({
    super.key,
    required this.institution,
    this.height = 34,
    this.width,
  });

  final Institution institution;
  final double height;

  /// Defaults to a wordmark-friendly 2.6 : 1 plate.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final w = width ?? height * 2.6;
    return Semantics(
      label: '${institution.name} logo',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: w,
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: height * 0.22,
          vertical: height * 0.18,
        ),
        decoration: BoxDecoration(
          color: institution.darkPlate
              ? const Color(0xFF17171C)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(height * 0.32),
        ),
        child: Image.asset(
          institution.asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          // Decode at display size, not at the file's full resolution.
          cacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
    );
  }
}
