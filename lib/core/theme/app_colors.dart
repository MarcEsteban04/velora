import 'package:flutter/material.dart';

/// Velora's color tokens.
///
/// The palette comes from the mascot: forest green from the cap and tee,
/// rust and cream from the red panda's fur. Keep raw hex values in this file
/// and reference these tokens everywhere else.
abstract final class AppColors {
  // Forest backdrop, darkest to lightest.
  static const forestNight = Color(0xFF07130D);
  static const forestDeep = Color(0xFF0C2016);
  static const forestMid = Color(0xFF16402A);
  static const forestCanopy = Color(0xFF2A6B40);
  static const forestMist = Color(0xFF6FAE72);

  // Brand green (the mascot's cap).
  static const leaf = Color(0xFF58A765);
  static const leafBright = Color(0xFF6CBF78);
  static const leafShadow = Color(0xFF34703F);

  // Red panda fur accents.
  static const rust = Color(0xFFD2682E);
  static const ember = Color(0xFFF0A15E);
  static const cream = Color(0xFFFBF1E4);

  // Surfaces.
  static const surface = Color(0xFF111A15);
  static const surfaceRaised = Color(0xFF18231D);

  // Text.
  static const textPrimary = Color(0xFFFBF7F1);
  static const textSecondary = Color(0xFFC9D6CC);
  static const textMuted = Color(0xFF8FA396);
  static const textOnLight = Color(0xFF1B2A20);
}
