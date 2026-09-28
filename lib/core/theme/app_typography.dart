import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale. Compact on purpose: phone screens favor density, so
/// headings stay on one line and cards show more at a glance.
///
/// Fredoka (rounded and playful) is for display text and the wordmark.
/// Nunito (rounded and very legible) is for everything else. Both are bundled
/// with the app, so text renders correctly offline.
abstract final class AppTypography {
  static const display = 'Fredoka';
  static const body = 'Nunito';

  static TextStyle get wordmark => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: 64,
    height: 1,
    letterSpacing: -1,
    color: AppColors.textPrimary,
  );

  static TextTheme get textTheme => TextTheme(
    displaySmall: TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.15,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w600,
      fontSize: 21,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w800,
      fontSize: 15,
      letterSpacing: 0.2,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w600,
      fontSize: 15,
      height: 1.4,
      color: AppColors.textSecondary,
    ),
    bodyMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.4,
      color: AppColors.textSecondary,
    ),
    labelMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 0.3,
      color: AppColors.textMuted,
    ),
  );
}
