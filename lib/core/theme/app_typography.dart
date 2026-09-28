import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale.
///
/// Fredoka (rounded and playful) is for display text and the wordmark.
/// Nunito (rounded and very legible) is for everything else. Both are bundled
/// with the app, so text renders correctly offline.
abstract final class AppTypography {
  static const display = 'Fredoka';
  static const body = 'Nunito';

  static const wordmark = TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: 64,
    height: 1,
    letterSpacing: -1,
    color: AppColors.textPrimary,
  );

  static const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 1.1,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w800,
      fontSize: 17,
      letterSpacing: 0.2,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w600,
      fontSize: 17,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    bodyMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w400,
      fontSize: 15,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    labelMedium: TextStyle(
      fontFamily: body,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 0.3,
      color: AppColors.textMuted,
    ),
  );
}
