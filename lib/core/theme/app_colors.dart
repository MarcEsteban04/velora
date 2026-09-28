import 'package:flutter/material.dart';

/// Velora's color tokens.
///
/// The brand colors come from the mascot: leaf green from the cap and tee,
/// rust and cream from the red panda's fur. The scene colors paint a
/// Himalayan dusk, the red panda's home. Keep raw hex values in this file and
/// reference these tokens everywhere else.
abstract final class AppColors {
  // Dusk sky, from zenith down to the horizon.
  static const skyZenith = Color(0xFF0B0D2A);
  static const skyIndigo = Color(0xFF1D1A4A);
  static const skyPlum = Color(0xFF4B2B62);
  static const skyRose = Color(0xFFA2485E);
  static const skyAmber = Color(0xFFF09A5A);

  // Mountain ridges, from farthest (hazy) to nearest (silhouette).
  static const ridgeFarTop = Color(0xFF7A4F7A);
  static const ridgeFarBase = Color(0xFF3A2A58);
  static const ridgeMidTop = Color(0xFF3A2856);
  static const ridgeMidBase = Color(0xFF221A40);
  static const ridgeNear = Color(0xFF16102A);
  static const night = Color(0xFF0A0818);

  static const mist = Color(0xFFD9C6E8);
  static const moon = Color(0xFFFFF4E0);

  // Brand green (the mascot's cap).
  static const leaf = Color(0xFF58A765);
  static const leafBright = Color(0xFF6CBF78);
  static const leafShadow = Color(0xFF34703F);

  // Red panda fur accents.
  static const rust = Color(0xFFD2682E);
  static const ember = Color(0xFFF0A15E);
  static const cream = Color(0xFFFBF1E4);

  // Supporting accents for icons and illustrations.
  static const sky = Color(0xFF8AB4FF);
  static const lilac = Color(0xFFB79CFF);

  // Surfaces.
  static const surface = Color(0xFF15122B);
  static const surfaceRaised = Color(0xFF1F1B3A);

  // Text.
  static const textPrimary = Color(0xFFFBF7F1);
  static const textSecondary = Color(0xFFD8D1E4);
  static const textMuted = Color(0xFF9D95B3);
  static const textOnLight = Color(0xFF1B2A20);
}
