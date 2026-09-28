import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The typefaces the user can pick in Settings. All are bundled (and
/// open-licensed), so text renders the same offline.
enum AppFont {
  /// Velora's own: Fredoka (rounded, playful) for headings, Nunito (rounded,
  /// very legible) for text.
  velora('Velora', 'Rounded and playful', display: 'Fredoka', body: 'Nunito'),

  /// Plus Jakarta Sans, the face Tarsi uses.
  jakarta(
    'Jakarta',
    'Clean and modern, the Tarsi look',
    display: 'PlusJakartaSans',
    body: 'PlusJakartaSans',
  ),
  figtree('Figtree', 'Friendly and warm', display: 'Figtree', body: 'Figtree'),
  outfit('Outfit', 'Geometric and crisp', display: 'Outfit', body: 'Outfit'),
  lexend('Lexend', 'Made for easy reading', display: 'Lexend', body: 'Lexend');

  const AppFont(
    this.label,
    this.description, {
    required this.display,
    required this.body,
  });

  final String label;
  final String description;
  final String display;
  final String body;
}

/// Type scale. Compact on purpose: phone screens favor density, so
/// headings stay on one line and cards show more at a glance.
///
/// The families come from [font], which the app root sets from Settings.
/// The wordmark is always Fredoka: it's the logo.
abstract final class AppTypography {
  static AppFont font = AppFont.velora;

  static String get display => font.display;
  static String get body => font.body;

  static const _brand = 'Fredoka';

  static TextStyle get wordmark => TextStyle(
    fontFamily: _brand,
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
